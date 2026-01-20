# frozen_string_literal: true

require_relative "ast"
require_relative "library_mapper"
require_relative "../ruby2faust/ir"

module Faust2Ruby
  # Converts Faust AST nodes to Ruby2Faust IR nodes.
  # This enables semantic analysis and Ruby code generation.
  class IRBuilder
    Node = Ruby2Faust::Node
    NodeType = Ruby2Faust::NodeType

    def initialize
      @definitions = {}  # name => AST::Definition
      @errors = []
    end

    attr_reader :errors

    # Build IR from a parsed program
    # Returns a hash with :process (the main process IR), :imports, :declares
    def build(program)
      # First pass: collect all definitions
      program.statements.each do |stmt|
        case stmt
        when AST::Definition
          @definitions[stmt.name] = stmt
        end
      end

      # Find process definition
      process_def = @definitions["process"]
      unless process_def
        @errors << "No 'process' definition found"
        return nil
      end

      # Build IR for process
      process_ir = build_expression(process_def.expression)

      # Collect imports and declares
      imports = program.statements.select { |s| s.is_a?(AST::Import) }.map(&:path)
      declares = program.statements.select { |s| s.is_a?(AST::Declare) }.to_h { |d| [d.key, d.value] }

      {
        process: process_ir,
        imports: imports,
        declares: declares,
        definitions: @definitions.reject { |k, _| k == "process" }
      }
    end

    private

    def build_expression(node)
      case node
      when AST::IntLiteral
        Node.new(type: NodeType::LITERAL, args: [node.value.to_s])

      when AST::FloatLiteral
        Node.new(type: NodeType::LITERAL, args: [node.value.to_s])

      when AST::StringLiteral
        # Strings in expressions are typically for UI labels
        Node.new(type: NodeType::LITERAL, args: ["\"#{node.value}\""])

      when AST::Wire
        Node.new(type: NodeType::WIRE)

      when AST::Cut
        Node.new(type: NodeType::CUT, channels: 0)

      when AST::Identifier
        build_identifier(node)

      when AST::QualifiedName
        build_qualified_name(node)

      when AST::BinaryOp
        build_binary_op(node)

      when AST::UnaryOp
        build_unary_op(node)

      when AST::FunctionCall
        build_function_call(node)

      when AST::UIElement
        build_ui_element(node)

      when AST::UIGroup
        build_ui_group(node)

      when AST::Iteration
        build_iteration(node)

      when AST::Lambda
        build_lambda(node)

      when AST::Waveform
        build_waveform(node)

      when AST::Table
        build_table(node)

      when AST::Route
        build_route(node)

      when AST::Prime
        build_prime(node)

      when AST::Access
        build_access(node)

      when AST::Paren
        build_expression(node.expression)

      when AST::With
        build_with(node)

      when AST::Letrec
        build_letrec(node)

      else
        @errors << "Unknown AST node type: #{node.class}"
        Node.new(type: NodeType::LITERAL, args: ["/* unknown */"])
      end
    end

    def build_identifier(node)
      name = node.name

      # Check if it's a known primitive
      if LibraryMapper::PRIMITIVES.key?(name)
        mapping = LibraryMapper::PRIMITIVES[name]
        if mapping[:args] == 0
          # Zero-arg primitive (used as prefix operator)
          Node.new(type: symbol_to_node_type(mapping[:dsl]))
        else
          # Primitive that needs args - return as literal
          Node.new(type: NodeType::LITERAL, args: [name])
        end
      elsif @definitions.key?(name)
        # Reference to a local definition
        build_expression(@definitions[name].expression)
      else
        # Unknown identifier - output as literal
        Node.new(type: NodeType::LITERAL, args: [name])
      end
    end

    def build_qualified_name(node)
      name = node.to_s

      # Check library mapping
      if LibraryMapper::MAPPINGS.key?(name)
        mapping = LibraryMapper::MAPPINGS[name]
        if mapping[:args] == 0
          # Zero-arg library function
          Node.new(type: symbol_to_node_type(mapping[:dsl]))
        else
          # Function that needs args - return as literal for now
          Node.new(type: NodeType::LITERAL, args: [name])
        end
      else
        Node.new(type: NodeType::LITERAL, args: [name])
      end
    end

    def build_binary_op(node)
      left = build_expression(node.left)
      right = build_expression(node.right)

      type = case node.op
             when :SEQ then NodeType::SEQ
             when :PAR then NodeType::PAR
             when :SPLIT then NodeType::SPLIT
             when :MERGE then NodeType::MERGE
             when :REC then NodeType::FEEDBACK
             when :ADD then NodeType::ADD
             when :SUB then NodeType::SUB
             when :MUL then NodeType::MUL
             when :DIV then NodeType::DIV
             when :MOD then NodeType::LITERAL  # Handle modulo
             when :POW then NodeType::POW
             when :DELAY then NodeType::DELAY  # @ operator
             else
               @errors << "Unknown binary operator: #{node.op}"
               NodeType::LITERAL
             end

      if type == NodeType::LITERAL
        # Fallback for unknown ops
        op_str = node.op.to_s.downcase
        Node.new(type: NodeType::LITERAL, args: ["(#{emit_ir(left)} #{op_str} #{emit_ir(right)})"])
      elsif type == NodeType::SPLIT
        # Split takes source + multiple targets, but binary op only has 2
        Node.new(type: type, inputs: [left, right], channels: right.channels)
      else
        # Calculate channels for composition operators
        channels = case type
                   when NodeType::SEQ then right.channels
                   when NodeType::PAR then (left.channels || 1) + (right.channels || 1)
                   when NodeType::MERGE then right.channels
                   when NodeType::FEEDBACK then left.channels
                   else 1
                   end
        Node.new(type: type, inputs: [left, right], channels: channels)
      end
    end

    def build_unary_op(node)
      operand = build_expression(node.operand)

      case node.op
      when :NEG
        Node.new(type: NodeType::NEG, inputs: [operand])
      else
        @errors << "Unknown unary operator: #{node.op}"
        operand
      end
    end

    def build_function_call(node)
      name = node.name
      args = node.args.map { |a| build_expression(a) }

      # Check library mapping
      mapping = LibraryMapper.lookup(name)
      if mapping
        build_mapped_function(mapping, args)
      elsif LibraryMapper.ui_element?(name)
        # This shouldn't happen - UI elements parsed separately
        Node.new(type: NodeType::LITERAL, args: ["#{name}(...)"])
      else
        # Unknown function - emit as literal
        args_str = args.map { |a| emit_ir(a) }.join(", ")
        Node.new(type: NodeType::LITERAL, args: ["#{name}(#{args_str})"])
      end
    end

    def build_mapped_function(mapping, args)
      dsl_method = mapping[:dsl]
      type = symbol_to_node_type(dsl_method)

      if type
        # Handle special cases with opts
        if mapping[:opts]
          # E.g., lowpass where first arg is order
          opts = mapping[:opts]
          order_idx = opts[:order]
          if order_idx
            order = args[order_idx]
            remaining = args.dup
            remaining.delete_at(order_idx)
            Node.new(type: type, args: [emit_ir(order).to_i], inputs: remaining)
          else
            Node.new(type: type, inputs: args)
          end
        else
          Node.new(type: type, inputs: args)
        end
      else
        # No direct type mapping - use literal
        Node.new(type: NodeType::LITERAL, args: [dsl_method.to_s])
      end
    end

    def build_ui_element(node)
      case node.type
      when :hslider
        init = build_expression(node.init)
        min = build_expression(node.min)
        max = build_expression(node.max)
        step = build_expression(node.step)
        Node.new(type: NodeType::SLIDER, args: [
          node.label,
          emit_ir(init),
          emit_ir(min),
          emit_ir(max),
          emit_ir(step)
        ])
      when :vslider
        init = build_expression(node.init)
        min = build_expression(node.min)
        max = build_expression(node.max)
        step = build_expression(node.step)
        Node.new(type: NodeType::VSLIDER, args: [
          node.label,
          emit_ir(init),
          emit_ir(min),
          emit_ir(max),
          emit_ir(step)
        ])
      when :nentry
        init = build_expression(node.init)
        min = build_expression(node.min)
        max = build_expression(node.max)
        step = build_expression(node.step)
        Node.new(type: NodeType::NENTRY, args: [
          node.label,
          emit_ir(init),
          emit_ir(min),
          emit_ir(max),
          emit_ir(step)
        ])
      when :button
        Node.new(type: NodeType::BUTTON, args: [node.label])
      when :checkbox
        Node.new(type: NodeType::CHECKBOX, args: [node.label])
      end
    end

    def build_ui_group(node)
      content = build_expression(node.content)
      type = case node.type
             when :hgroup then NodeType::HGROUP
             when :vgroup then NodeType::VGROUP
             when :tgroup then NodeType::TGROUP
             end
      Node.new(type: type, args: [node.label], inputs: [content], channels: content.channels)
    end

    def build_iteration(node)
      type = case node.type
             when :par then NodeType::FPAR
             when :seq then NodeType::FSEQ
             when :sum then NodeType::FSUM
             when :prod then NodeType::FPROD
             end

      # Store the body AST for later evaluation
      # We'll need to convert this to a block during Ruby generation
      count = build_expression(node.count)

      Node.new(
        type: type,
        args: [node.var.to_sym, emit_ir(count), node.body],  # Keep AST body for later
        channels: type == NodeType::FPAR ? emit_ir(count).to_i : 1
      )
    end

    def build_lambda(node)
      # Store params and body AST
      Node.new(
        type: NodeType::LAMBDA,
        args: [node.params.map(&:to_sym), node.body]  # Keep AST body for later
      )
    end

    def build_waveform(node)
      values = node.values.map { |v| emit_ir(build_expression(v)) }
      Node.new(type: NodeType::WAVEFORM, args: values)
    end

    def build_table(node)
      args = node.args.map { |a| build_expression(a) }
      type = node.type == :rdtable ? NodeType::RDTABLE : NodeType::RWTABLE
      Node.new(type: type, inputs: args)
    end

    def build_route(node)
      ins = emit_ir(build_expression(node.ins))
      outs = emit_ir(build_expression(node.outs))
      connections = node.connections.map do |from, to|
        [emit_ir(build_expression(from)), emit_ir(build_expression(to))]
      end
      Node.new(type: NodeType::ROUTE, args: [ins.to_i, outs.to_i, connections], channels: outs.to_i)
    end

    def build_prime(node)
      # Prime (') is one-sample delay, equivalent to mem
      operand = build_expression(node.operand)
      Node.new(type: NodeType::SEQ, inputs: [operand, Node.new(type: NodeType::MEM)])
    end

    def build_access(node)
      # Bracket access - often for component outputs
      operand = build_expression(node.operand)
      index = build_expression(node.index)
      Node.new(type: NodeType::LITERAL, args: ["#{emit_ir(operand)}[#{emit_ir(index)}]"])
    end

    def build_with(node)
      # With clauses define local scope - for now, inline
      build_expression(node.expression)
    end

    def build_letrec(node)
      # Letrec for recursive definitions - complex, emit as literal for now
      Node.new(type: NodeType::REC, args: [node])
    end

    # Convert DSL method symbol to NodeType
    def symbol_to_node_type(sym)
      const_name = sym.to_s.upcase.gsub(/_$/, "")
      Ruby2Faust::NodeType.const_get(const_name) rescue nil
    end

    # Simple IR to string for embedding in literals
    def emit_ir(node)
      return node.to_s unless node.is_a?(Node)

      case node.type
      when NodeType::LITERAL then node.args[0].to_s
      when NodeType::WIRE then "_"
      when NodeType::CUT then "!"
      else node.args[0].to_s rescue "?"
      end
    end
  end
end

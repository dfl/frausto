# frozen_string_literal: true

require_relative "ast"
require_relative "library_mapper"

module Faust2Ruby
  # Generates idiomatic Ruby DSL code from Faust AST.
  # Produces code compatible with the ruby2faust gem.
  class RubyGenerator
    def initialize(options = {})
      @indent = options.fetch(:indent, 2)
      @expression_only = options.fetch(:expression_only, false)
      @definitions = {}
    end

    # Generate Ruby code from a parsed Faust program
    def generate(program)
      lines = []

      # Collect definitions for reference
      program.statements.each do |stmt|
        @definitions[stmt.name] = stmt if stmt.is_a?(AST::Definition)
      end

      # Collect imports and declares
      imports = program.statements.select { |s| s.is_a?(AST::Import) }.map(&:path)
      declares = program.statements.select { |s| s.is_a?(AST::Declare) }

      unless @expression_only
        lines << "require 'ruby2faust'"
        lines << "include Ruby2Faust::DSL"
        lines << ""

        # Generate declares as comments
        declares.each do |stmt|
          lines << "# declare #{stmt.key} \"#{stmt.value}\""
        end

        lines << "" if declares.any?

        # Generate helper definitions (excluding process)
        program.statements.each do |stmt|
          if stmt.is_a?(AST::Definition) && stmt.name != "process"
            lines << generate_definition(stmt)
            lines << ""
          end
        end
      end

      # Generate process
      process_def = @definitions["process"]
      if process_def
        if @expression_only
          lines << generate_expression(process_def.expression)
        else
          lines << "process = #{generate_expression(process_def.expression)}"
          lines << ""

          # Build program with imports and declares
          lines << "prog = Ruby2Faust::Program.new(process)"
          imports.each do |imp|
            lines << "  .import(#{imp.inspect})" unless imp == "stdfaust.lib"
          end
          declares.each do |d|
            lines << "  .declare(:#{d.key}, #{d.value.inspect})"
          end
          lines << ""
          lines << "puts Ruby2Faust::Emitter.program(prog)"
        end
      end

      lines.join("\n")
    end

    # Generate just the expression part (for embedding)
    def generate_expression(node)
      case node
      when AST::IntLiteral
        node.value.to_s

      when AST::FloatLiteral
        node.value.to_s

      when AST::StringLiteral
        node.value.inspect

      when AST::Wire
        "wire"

      when AST::Cut
        "cut"

      when AST::Identifier
        generate_identifier(node)

      when AST::QualifiedName
        generate_qualified_name(node)

      when AST::BinaryOp
        generate_binary_op(node)

      when AST::UnaryOp
        generate_unary_op(node)

      when AST::FunctionCall
        generate_function_call(node)

      when AST::UIElement
        generate_ui_element(node)

      when AST::UIGroup
        generate_ui_group(node)

      when AST::Iteration
        generate_iteration(node)

      when AST::Lambda
        generate_lambda(node)

      when AST::Waveform
        generate_waveform(node)

      when AST::Table
        generate_table(node)

      when AST::Route
        generate_route(node)

      when AST::Prime
        generate_prime(node)

      when AST::Access
        generate_access(node)

      when AST::Paren
        "(#{generate_expression(node.expression)})"

      when AST::With
        generate_with(node)

      when AST::Letrec
        generate_letrec(node)

      else
        "literal(\"/* unknown: #{node.class} */\")"
      end
    end

    private

    def generate_definition(stmt)
      if stmt.params.empty?
        "#{stmt.name} = #{generate_expression(stmt.expression)}"
      else
        params_str = stmt.params.join(", ")
        "def #{stmt.name}(#{params_str})\n  #{generate_expression(stmt.expression)}\nend"
      end
    end

    def generate_identifier(node)
      name = node.name

      # Check for known primitives that become method calls
      if LibraryMapper::PRIMITIVES.key?(name)
        mapping = LibraryMapper::PRIMITIVES[name]
        if mapping[:args] == 0
          mapping[:dsl].to_s
        else
          name  # Function reference
        end
      elsif name == "mem"
        "mem"
      else
        name
      end
    end

    def generate_qualified_name(node)
      name = node.to_s

      # Check library mapping
      mapping = LibraryMapper.lookup(name)
      if mapping
        if mapping[:args] == 0
          mapping[:dsl].to_s
        else
          # Return as a method name for partial application
          mapping[:dsl].to_s
        end
      else
        "literal(#{name.inspect})"
      end
    end

    def generate_binary_op(node)
      left = generate_expression(node.left)
      right = generate_expression(node.right)

      case node.op
      when :SEQ
        "(#{left} >> #{right})"
      when :PAR
        "(#{left} | #{right})"
      when :SPLIT
        "#{left}.split(#{right})"
      when :MERGE
        "#{left}.merge(#{right})"
      when :REC
        "(#{left} ~ #{right})"
      when :ADD
        "(#{left} + #{right})"
      when :SUB
        "(#{left} - #{right})"
      when :MUL
        "(#{left} * #{right})"
      when :DIV
        "(#{left} / #{right})"
      when :MOD
        "literal(\"(#{left} % #{right})\")"
      when :POW
        "pow(#{left}, #{right})"
      when :DELAY
        "delay(#{left}, #{right})"
      when :AND
        "literal(\"(#{left} & #{right})\")"
      when :OR
        "literal(\"(#{left} | #{right})\")"
      when :LT
        "literal(\"(#{left} < #{right})\")"
      when :GT
        "literal(\"(#{left} > #{right})\")"
      when :LE
        "literal(\"(#{left} <= #{right})\")"
      when :GE
        "literal(\"(#{left} >= #{right})\")"
      when :EQ
        "literal(\"(#{left} == #{right})\")"
      when :NEQ
        "literal(\"(#{left} != #{right})\")"
      else
        "literal(\"(#{left} #{node.op} #{right})\")"
      end
    end

    def generate_unary_op(node)
      operand = generate_expression(node.operand)

      case node.op
      when :NEG
        "(-#{operand})"
      else
        "literal(\"#{node.op}(#{operand})\")"
      end
    end

    def generate_function_call(node)
      name = node.name
      args = node.args.map { |a| generate_expression(a) }

      # Handle prefix operator forms
      case name
      when "*"
        # *(x) -> gain(x)
        if args.length == 1
          return "gain(#{args[0]})"
        else
          return "(#{args.join(' * ')})"
        end
      when "+"
        return args.length == 1 ? args[0] : "(#{args.join(' + ')})"
      when "-"
        return args.length == 1 ? "(-#{args[0]})" : "(#{args.join(' - ')})"
      when "/"
        return args.length == 1 ? "literal(\"/(#{args[0]})\")" : "(#{args.join(' / ')})"
      end

      # Check library mapping
      mapping = LibraryMapper.lookup(name)
      if mapping
        generate_mapped_call(mapping, args, name)
      else
        # Unknown function - emit as literal
        "literal(\"#{name}(#{args.join(', ')})\")"
      end
    end

    def generate_mapped_call(mapping, args, original_name)
      dsl_method = mapping[:dsl]

      case dsl_method
      when :lp, :hp
        # fi.lowpass(order, freq) -> lp(freq, order: order)
        if args.length >= 2
          order = args[0]
          freq = args[1]
          "#{dsl_method}(#{freq}, order: #{order})"
        else
          "#{dsl_method}(#{args.join(', ')})"
        end

      when :slider
        # hslider already parsed as UIElement
        "#{dsl_method}(#{args.join(', ')})"

      when :selectn
        # ba.selectn(n, idx, ...) -> selectn(n, idx, ...)
        "selectn(#{args.join(', ')})"

      else
        # Standard call
        if args.empty?
          dsl_method.to_s
        else
          "#{dsl_method}(#{args.join(', ')})"
        end
      end
    end

    def generate_ui_element(node)
      case node.type
      when :hslider
        init = generate_expression(node.init)
        min = generate_expression(node.min)
        max = generate_expression(node.max)
        step = generate_expression(node.step)
        "slider(#{node.label.inspect}, init: #{init}, min: #{min}, max: #{max}, step: #{step})"

      when :vslider
        init = generate_expression(node.init)
        min = generate_expression(node.min)
        max = generate_expression(node.max)
        step = generate_expression(node.step)
        "vslider(#{node.label.inspect}, init: #{init}, min: #{min}, max: #{max}, step: #{step})"

      when :nentry
        init = generate_expression(node.init)
        min = generate_expression(node.min)
        max = generate_expression(node.max)
        step = generate_expression(node.step)
        "nentry(#{node.label.inspect}, init: #{init}, min: #{min}, max: #{max}, step: #{step})"

      when :button
        "button(#{node.label.inspect})"

      when :checkbox
        "checkbox(#{node.label.inspect})"
      end
    end

    def generate_ui_group(node)
      content = generate_expression(node.content)

      case node.type
      when :hgroup
        "hgroup(#{node.label.inspect}) { #{content} }"
      when :vgroup
        "vgroup(#{node.label.inspect}) { #{content} }"
      when :tgroup
        "tgroup(#{node.label.inspect}) { #{content} }"
      end
    end

    def generate_iteration(node)
      var = node.var
      count = generate_expression(node.count)
      body = generate_expression(node.body)

      method = case node.type
               when :par then "fpar"
               when :seq then "fseq"
               when :sum then "fsum"
               when :prod then "fprod"
               end

      "#{method}(:#{var}, #{count}) { |#{var}| #{body} }"
    end

    def generate_lambda(node)
      params = node.params.join(", ")
      body = generate_expression(node.body)

      if node.params.length == 1
        "flambda(:#{node.params[0]}) { |#{params}| #{body} }"
      else
        params_syms = node.params.map { |p| ":#{p}" }.join(", ")
        "flambda(#{params_syms}) { |#{params}| #{body} }"
      end
    end

    def generate_waveform(node)
      values = node.values.map { |v| generate_expression(v) }
      "waveform(#{values.join(', ')})"
    end

    def generate_table(node)
      args = node.args.map { |a| generate_expression(a) }

      case node.type
      when :rdtable
        "rdtable(#{args.join(', ')})"
      when :rwtable
        "rwtable(#{args.join(', ')})"
      end
    end

    def generate_route(node)
      ins = generate_expression(node.ins)
      outs = generate_expression(node.outs)
      connections = node.connections.map do |from, to|
        "[#{generate_expression(from)}, #{generate_expression(to)}]"
      end
      "route(#{ins}, #{outs}, [#{connections.join(', ')}])"
    end

    def generate_prime(node)
      operand = generate_expression(node.operand)
      "(#{operand} >> mem)"
    end

    def generate_access(node)
      operand = generate_expression(node.operand)
      index = generate_expression(node.index)
      "literal(\"#{operand}[#{index}]\")"
    end

    def generate_with(node)
      # With clauses need special handling for local definitions
      # For now, just generate the expression
      generate_expression(node.expression)
    end

    def generate_letrec(node)
      # Letrec is complex - generate as literal for now
      defs = node.definitions.map do |d|
        "#{d.name} = #{generate_expression(d.expression)}"
      end.join("; ")
      expr = node.expression ? generate_expression(node.expression) : "wire"
      "literal(\"letrec { #{defs} } #{expr}\")"
    end
  end
end

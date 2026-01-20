# frozen_string_literal: true

module Faust2Ruby
  # AST nodes for Faust DSP programs.
  # These represent the parsed structure before conversion to Ruby2Faust IR.
  module AST
    # Base class for all AST nodes
    class Node
      attr_reader :line, :column

      def initialize(line: nil, column: nil)
        @line = line
        @column = column
      end
    end

    # Complete Faust program
    class Program < Node
      attr_reader :statements

      def initialize(statements, **opts)
        super(**opts)
        @statements = statements
      end
    end

    # Import statement: import("stdfaust.lib");
    class Import < Node
      attr_reader :path

      def initialize(path, **opts)
        super(**opts)
        @path = path
      end
    end

    # Declare statement: declare name "author";
    class Declare < Node
      attr_reader :key, :value

      def initialize(key, value, **opts)
        super(**opts)
        @key = key
        @value = value
      end
    end

    # Definition: name = expression;
    class Definition < Node
      attr_reader :name, :params, :expression

      def initialize(name, expression, params: [], **opts)
        super(**opts)
        @name = name
        @params = params
        @expression = expression
      end
    end

    # Binary operation: left OP right
    class BinaryOp < Node
      attr_reader :op, :left, :right

      def initialize(op, left, right, **opts)
        super(**opts)
        @op = op
        @left = left
        @right = right
      end
    end

    # Unary operation: OP operand (e.g., negation)
    class UnaryOp < Node
      attr_reader :op, :operand

      def initialize(op, operand, **opts)
        super(**opts)
        @op = op
        @operand = operand
      end
    end

    # Function call: func(arg1, arg2, ...)
    class FunctionCall < Node
      attr_reader :name, :args

      def initialize(name, args, **opts)
        super(**opts)
        @name = name
        @args = args
      end
    end

    # Qualified name: os.osc, fi.lowpass, etc.
    class QualifiedName < Node
      attr_reader :parts

      def initialize(parts, **opts)
        super(**opts)
        @parts = parts
      end

      def to_s
        parts.join(".")
      end
    end

    # Identifier reference
    class Identifier < Node
      attr_reader :name

      def initialize(name, **opts)
        super(**opts)
        @name = name
      end
    end

    # Integer literal
    class IntLiteral < Node
      attr_reader :value

      def initialize(value, **opts)
        super(**opts)
        @value = value
      end
    end

    # Float literal
    class FloatLiteral < Node
      attr_reader :value

      def initialize(value, **opts)
        super(**opts)
        @value = value
      end
    end

    # String literal
    class StringLiteral < Node
      attr_reader :value

      def initialize(value, **opts)
        super(**opts)
        @value = value
      end
    end

    # Wire primitive: _
    class Wire < Node
    end

    # Cut primitive: !
    class Cut < Node
    end

    # Iteration: par(i, n, expr), seq(i, n, expr), etc.
    class Iteration < Node
      attr_reader :type, :var, :count, :body

      def initialize(type, var, count, body, **opts)
        super(**opts)
        @type = type  # :par, :seq, :sum, :prod
        @var = var
        @count = count
        @body = body
      end
    end

    # Lambda: \(x, y).(body)
    class Lambda < Node
      attr_reader :params, :body

      def initialize(params, body, **opts)
        super(**opts)
        @params = params
        @body = body
      end
    end

    # With clause: expr with { defs }
    class With < Node
      attr_reader :expression, :definitions

      def initialize(expression, definitions, **opts)
        super(**opts)
        @expression = expression
        @definitions = definitions
      end
    end

    # Letrec clause: letrec { defs }
    class Letrec < Node
      attr_reader :definitions, :expression

      def initialize(definitions, expression, **opts)
        super(**opts)
        @definitions = definitions
        @expression = expression
      end
    end

    # UI element: hslider, vslider, nentry, button, checkbox
    class UIElement < Node
      attr_reader :type, :label, :init, :min, :max, :step

      def initialize(type, label, init: nil, min: nil, max: nil, step: nil, **opts)
        super(**opts)
        @type = type
        @label = label
        @init = init
        @min = min
        @max = max
        @step = step
      end
    end

    # UI group: hgroup, vgroup, tgroup
    class UIGroup < Node
      attr_reader :type, :label, :content

      def initialize(type, label, content, **opts)
        super(**opts)
        @type = type
        @label = label
        @content = content
      end
    end

    # Waveform: waveform{v1, v2, ...}
    class Waveform < Node
      attr_reader :values

      def initialize(values, **opts)
        super(**opts)
        @values = values
      end
    end

    # Table operations: rdtable, rwtable
    class Table < Node
      attr_reader :type, :args

      def initialize(type, args, **opts)
        super(**opts)
        @type = type
        @args = args
      end
    end

    # Delay with prime: expr'
    class Prime < Node
      attr_reader :operand

      def initialize(operand, **opts)
        super(**opts)
        @operand = operand
      end
    end

    # Access with brackets: expr[n]
    class Access < Node
      attr_reader :operand, :index

      def initialize(operand, index, **opts)
        super(**opts)
        @operand = operand
        @index = index
      end
    end

    # Parenthesized expression
    class Paren < Node
      attr_reader :expression

      def initialize(expression, **opts)
        super(**opts)
        @expression = expression
      end
    end

    # Route: route(ins, outs, connections)
    class Route < Node
      attr_reader :ins, :outs, :connections

      def initialize(ins, outs, connections, **opts)
        super(**opts)
        @ins = ins
        @outs = outs
        @connections = connections
      end
    end

    # Case expression: case { (pattern) => expr; ... }
    # Each branch is a CaseBranch with pattern and result
    class CaseExpr < Node
      attr_reader :branches

      def initialize(branches, **opts)
        super(**opts)
        @branches = branches
      end
    end

    # A single branch in a case expression
    class CaseBranch < Node
      attr_reader :pattern, :result

      def initialize(pattern, result, **opts)
        super(**opts)
        @pattern = pattern  # Can be IntLiteral, Identifier (variable), or Paren
        @result = result
      end
    end
  end
end

# frozen_string_literal: true

require_relative "faust2ruby/version"
require_relative "faust2ruby/lexer"
require_relative "faust2ruby/ast"
require_relative "faust2ruby/parser"
require_relative "faust2ruby/library_mapper"
require_relative "faust2ruby/ir_builder"
require_relative "faust2ruby/ruby_generator"

module Faust2Ruby
  class Error < StandardError; end
  class ParseError < Error; end

  # Convert Faust source code to Ruby DSL code.
  #
  # @param source [String] Faust DSP source code
  # @param options [Hash] Conversion options
  # @option options [Boolean] :expression_only Output only the process expression
  # @option options [Integer] :indent Indentation level (default: 2)
  # @return [String] Ruby DSL code
  #
  # @example
  #   faust_code = 'process = os.osc(440) : *(0.5);'
  #   ruby_code = Faust2Ruby.to_ruby(faust_code)
  #   # => "osc(440) >> gain(0.5)"
  #
  def self.to_ruby(source, **options)
    parser = Parser.new(source)
    program = parser.parse

    unless parser.errors.empty?
      raise ParseError, "Parse errors:\n#{parser.errors.join("\n")}"
    end

    generator = RubyGenerator.new(options)
    generator.generate(program)
  end

  # Parse Faust source and return the AST.
  #
  # @param source [String] Faust DSP source code
  # @return [AST::Program] Parsed program
  #
  def self.parse(source)
    parser = Parser.new(source)
    program = parser.parse

    unless parser.errors.empty?
      raise ParseError, "Parse errors:\n#{parser.errors.join("\n")}"
    end

    program
  end

  # Tokenize Faust source and return tokens.
  #
  # @param source [String] Faust DSP source code
  # @return [Array<Lexer::Token>] Token array
  #
  def self.tokenize(source)
    lexer = Lexer.new(source)
    lexer.tokenize
  end

  # Convert Faust file to Ruby DSL.
  #
  # @param input_path [String] Path to Faust .dsp file
  # @param output_path [String, nil] Output path (nil for stdout)
  # @param options [Hash] Conversion options
  #
  def self.convert_file(input_path, output_path = nil, **options)
    source = File.read(input_path)
    ruby_code = to_ruby(source, **options)

    if output_path
      File.write(output_path, ruby_code)
    else
      ruby_code
    end
  end
end

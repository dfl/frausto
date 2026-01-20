# frozen_string_literal: true

require_relative "../test_helper"
require "faust2ruby"

class Faust2Ruby::LexerTest < Minitest::Test
  def tokenize(source)
    Faust2Ruby::Lexer.new(source).tokenize
  end

  def test_tokenize_integer
    tokens = tokenize("42")
    assert_equal :INT, tokens[0].type
    assert_equal 42, tokens[0].value
  end

  def test_tokenize_float
    tokens = tokenize("3.14")
    assert_equal :FLOAT, tokens[0].type
    assert_equal 3.14, tokens[0].value
  end

  def test_tokenize_float_with_exponent
    tokens = tokenize("1e-3")
    assert_equal :FLOAT, tokens[0].type
    assert_equal 0.001, tokens[0].value
  end

  def test_tokenize_string
    tokens = tokenize('"hello world"')
    assert_equal :STRING, tokens[0].type
    assert_equal "hello world", tokens[0].value
  end

  def test_tokenize_string_with_escapes
    tokens = tokenize('"line1\\nline2"')
    assert_equal :STRING, tokens[0].type
    assert_equal "line1\nline2", tokens[0].value
  end

  def test_tokenize_identifier
    tokens = tokenize("freq")
    assert_equal :IDENT, tokens[0].type
    assert_equal "freq", tokens[0].value
  end

  def test_tokenize_keywords
    %w[import declare process with letrec par seq sum prod].each do |kw|
      tokens = tokenize(kw)
      assert_equal kw.upcase.to_sym, tokens[0].type, "Expected #{kw} to be recognized as keyword"
    end
  end

  def test_tokenize_wire
    tokens = tokenize("_")
    assert_equal :WIRE, tokens[0].type
  end

  def test_tokenize_cut
    tokens = tokenize("!")
    assert_equal :CUT, tokens[0].type
  end

  def test_tokenize_operators
    {
      ":" => :SEQ,
      "," => :PAR,
      "~" => :REC,
      "<:" => :SPLIT,
      ":>" => :MERGE,
      "+" => :ADD,
      "-" => :SUB,
      "*" => :MUL,
      "/" => :DIV,
      "^" => :POW,
      "@" => :DELAY,
      "'" => :PRIME,
      "=" => :DEF,
      ";" => :ENDDEF,
    }.each do |op, expected_type|
      tokens = tokenize(op)
      assert_equal expected_type, tokens[0].type, "Expected '#{op}' to be #{expected_type}"
    end
  end

  def test_tokenize_parentheses
    tokens = tokenize("()")
    assert_equal :LPAREN, tokens[0].type
    assert_equal :RPAREN, tokens[1].type
  end

  def test_tokenize_braces
    tokens = tokenize("{}")
    assert_equal :LBRACE, tokens[0].type
    assert_equal :RBRACE, tokens[1].type
  end

  def test_skip_line_comment
    tokens = tokenize("42 // comment\n43")
    assert_equal :INT, tokens[0].type
    assert_equal 42, tokens[0].value
    assert_equal :INT, tokens[1].type
    assert_equal 43, tokens[1].value
  end

  def test_skip_block_comment
    tokens = tokenize("42 /* comment */ 43")
    assert_equal :INT, tokens[0].type
    assert_equal 42, tokens[0].value
    assert_equal :INT, tokens[1].type
    assert_equal 43, tokens[1].value
  end

  def test_skip_nested_block_comment
    tokens = tokenize("42 /* outer /* inner */ outer */ 43")
    assert_equal :INT, tokens[0].type
    assert_equal :INT, tokens[1].type
  end

  def test_tokenize_simple_expression
    tokens = tokenize("os.osc(440)")
    types = tokens.map(&:type)
    assert_equal [:IDENT, :DOT, :IDENT, :LPAREN, :INT, :RPAREN, :EOF], types
  end

  def test_tokenize_process_definition
    tokens = tokenize('process = os.osc(440);')
    types = tokens.map(&:type)
    assert_equal [:PROCESS, :DEF, :IDENT, :DOT, :IDENT, :LPAREN, :INT, :RPAREN, :ENDDEF, :EOF], types
  end

  def test_line_tracking
    tokens = tokenize("a\nb\nc")
    assert_equal 1, tokens[0].line
    assert_equal 2, tokens[1].line
    assert_equal 3, tokens[2].line
  end

  def test_lambda_token
    tokens = tokenize('\\(x).(x)')
    assert_equal :LAMBDA, tokens[0].type
  end
end

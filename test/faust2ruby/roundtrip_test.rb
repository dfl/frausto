# frozen_string_literal: true

require_relative "../test_helper"
require "faust2ruby"
require "ruby2faust"

class Faust2Ruby::RoundtripTest < Minitest::Test
  include Ruby2Faust::DSL

  # Test that Faust -> Ruby -> Faust produces semantically equivalent code

  def roundtrip(faust_source)
    # Parse and generate Ruby
    ruby_code = Faust2Ruby.to_ruby(faust_source, expression_only: true)

    # Evaluate Ruby to get DSP
    dsp = eval(ruby_code)

    # Generate Faust from DSP
    Ruby2Faust::Emitter.emit(dsp.node)
  end

  def test_roundtrip_osc
    faust = "process = os.osc(440);"
    result = roundtrip(faust)
    assert_includes result, "os.osc(440)"
  end

  def test_roundtrip_sequential
    faust = "process = os.osc(440) : *(0.5);"
    result = roundtrip(faust)
    assert_includes result, "os.osc(440)"
    assert_includes result, ":"
    assert_includes result, "0.5"
  end

  def test_roundtrip_parallel
    faust = "process = os.osc(440) , os.osc(880);"
    result = roundtrip(faust)
    assert_includes result, "os.osc(440)"
    assert_includes result, ","
    assert_includes result, "os.osc(880)"
  end

  def test_roundtrip_slider
    faust = 'process = hslider("freq", 440, 20, 20000, 1);'
    result = roundtrip(faust)
    assert_includes result, 'hslider("freq"'
    assert_includes result, "440"
  end

  def test_roundtrip_filter
    faust = "process = fi.lowpass(2, 1000);"
    result = roundtrip(faust)
    assert_includes result, "fi.lowpass(2"
    assert_includes result, "1000"
  end

  def test_roundtrip_noise
    faust = "process = no.noise;"
    result = roundtrip(faust)
    assert_includes result, "no.noise"
  end

  def test_roundtrip_wire
    faust = "process = _;"
    result = roundtrip(faust)
    assert_equal "_", result
  end

  def test_roundtrip_gain
    faust = "process = *(0.5);"
    result = roundtrip(faust)
    assert_includes result, "*(0.5)"
  end

  def test_roundtrip_complex_chain
    faust = "process = os.osc(440) : fi.lowpass(1, 800) : *(0.3);"
    result = roundtrip(faust)
    assert_includes result, "os.osc(440)"
    assert_includes result, "fi.lowpass"
    assert_includes result, "0.3"
  end

  def test_roundtrip_button
    faust = 'process = button("trigger");'
    result = roundtrip(faust)
    assert_includes result, 'button("trigger")'
  end

  def test_roundtrip_checkbox
    faust = 'process = checkbox("enable");'
    result = roundtrip(faust)
    assert_includes result, 'checkbox("enable")'
  end

  def test_roundtrip_arithmetic
    # Arithmetic with known DSP nodes
    faust = "process = os.osc(440) + os.osc(220);"
    result = roundtrip(faust)
    assert_includes result, "os.osc"
    assert_includes result, "+"
  end

  def test_roundtrip_delay
    faust = "process = de.delay(1000, 500);"
    result = roundtrip(faust)
    assert_includes result, "de.delay"
    assert_includes result, "1000"
    assert_includes result, "500"
  end

  def test_roundtrip_adsr
    # Use a button instead of unknown 'gate' variable
    faust = 'process = en.adsr(0.1, 0.2, 0.7, 0.3, button("gate"));'
    result = roundtrip(faust)
    assert_includes result, "en.adsr"
    assert_includes result, "0.1"
    assert_includes result, "0.7"
  end
end

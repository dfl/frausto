# Ruby2Faust

A Ruby DSL that generates Faust DSP code. Ruby describes the graph; Faust compiles and runs it.

## Installation

```bash
gem install ruby2faust
```

Or add to your Gemfile:

```ruby
gem 'ruby2faust'
```

## Quick Start

```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

process = osc(440).then(gain(0.3))
puts Ruby2Faust::Emitter.program(process)
```

Output:
```faust
import("stdfaust.lib");

process = (os.osc(440) : *(0.3));
```

## DSL Reference

### Oscillators (os.)
```ruby
osc(freq)       # Sine wave
saw(freq)       # Sawtooth
square(freq)    # Square wave
triangle(freq)  # Triangle wave
lf_saw(freq)    # Low-freq sawtooth (0-1)
imptrain(freq)  # Impulse train
phasor(n, freq) # Table phasor
```

### Noise (no.)
```ruby
noise       # White noise
pink_noise  # Pink noise
```

### Filters (fi.)
```ruby
lp(freq, order: 1)       # Lowpass
hp(freq, order: 1)       # Highpass
bp(freq, q: 1)           # Bandpass
resonlp(freq, q, gain)   # Resonant lowpass
resonhp(freq, q, gain)   # Resonant highpass
allpass(max, d, fb)      # Allpass comb
dcblock                  # DC blocker
peak_eq(freq, q, db)     # Parametric EQ
```

### Delays (de.)
```ruby
delay(max, samples)      # Integer delay
fdelay(max, samples)     # Fractional delay
sdelay(max, interp, d)   # Smooth delay
```

### Envelopes (en.)
```ruby
ar(attack, release, gate)
asr(attack, sustain, release, gate)
adsr(attack, decay, sustain, release, gate)
adsre(attack, decay, sustain, release, gate)  # Exponential
```

### Math
```ruby
gain(x)     # Multiply
add         # Sum (+)
mul         # Multiply (*)
sub         # Subtract (-)
div         # Divide (/)
abs_        # Absolute value
min_(a, b)  # Minimum
max_(a, b)  # Maximum
clip(min, max)  # Clamp
pow(base, exp)
sqrt_, exp_, log_, log10_
sin_, cos_, tan_, tanh_
floor_, ceil_, rint_
```

### Conversion (ba.)
```ruby
db2linear(x)   # dB to linear
linear2db(x)   # Linear to dB
midi2hz(x)     # MIDI note to Hz
hz2midi(x)     # Hz to MIDI note
samp2sec(x)    # Samples to seconds
sec2samp(x)    # Seconds to samples
```

### Smoothing (si.)
```ruby
smooth(tau)    # Smooth with time constant
smoo           # Default 5ms smooth
```

### Selectors
```ruby
select2(cond, a, b)          # 2-way select
selectn(n, index, *signals)  # N-way select
```

### Routing (si.)
```ruby
bus(n)    # N parallel wires
block(n)  # Terminate N signals
```

### Reverbs (re.)
```ruby
freeverb(fb1, fb2, damp, spread)
zita_rev(rdel, f1, f2, t60dc, t60m, fsmax)
jpverb(t60, damp, size, ...)
```

### Compressors (co.)
```ruby
compressor(ratio, thresh, attack, release)
limiter
```

### Spatial (sp.)
```ruby
panner(pan)  # Stereo panner (0-1)
```

### UI Controls
```ruby
slider("name", init:, min:, max:, step: 0.01)
vslider("name", init:, min:, max:, step: 0.01)
nentry("name", init:, min:, max:, step: 1)
button("name")
checkbox("name")
hgroup("name", content)
vgroup("name", content)
```

### Composition Operators

| Ruby        | Faust | Meaning    |
|-------------|-------|------------|
| `.then(b)`  | `:`   | Sequential |
| `.par(b)`   | `,`   | Parallel   |
| `.split(*bs)` | `<:` | Fan-out   |
| `.merge(b)` | `:>`  | Fan-in     |
| `.feedback(b)` | `~` | Feedback  |

Aliases: `>>` for `.then`, `|` for `.par`

### Constants
```ruby
sr    # Sample rate (ma.SR)
pi    # Pi (ma.PI)
```

### Utility
```ruby
wire     # Pass-through (_)
cut      # Terminate (!)
mem      # 1-sample delay
literal("expr")  # Raw Faust expression
```

## Metadata & Imports

```ruby
prog = Ruby2Faust::Program.new(process)
  .declare(:name, "MySynth")
  .declare(:author, "Me")
  .import("analyzers.lib")

puts Ruby2Faust::Emitter.program(prog)
```

## Example: Subtractive Synth

```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

gate = button("gate")
freq = slider("freq", init: 220, min: 20, max: 2000).then(smoo)
cutoff = slider("cutoff", init: 1000, min: 100, max: 8000).then(smoo)

env = adsr(0.01, 0.2, 0.6, 0.3, gate)

process = saw(freq)
  .then(resonlp(cutoff, 4, 1))
  .then(gain(env))
  .then(panner(0.5))

prog = Ruby2Faust::Program.new(process)
  .declare(:name, "SubSynth")

puts Ruby2Faust::Emitter.program(prog)
```

## CLI

```bash
ruby2faust compile synth.rb           # Generate .dsp
ruby2faust compile -o out.dsp synth.rb
ruby2faust run synth.rb               # Compile + run Faust
```

## Live Reload

```ruby
if Ruby2Faust::Live.changed?(old_graph, new_graph)
  Ruby2Faust::Live.compile(new_graph, output: "synth.dsp")
end
```

## License

MIT

# faust2ruby

Convert Faust DSP code to Ruby DSL code compatible with ruby2faust.

## Installation

```bash
gem install frausto
```

## Usage

### Command Line

```bash
# Convert a Faust file to Ruby
faust2ruby input.dsp -o output.rb

# Output only the process expression (no boilerplate)
faust2ruby -e input.dsp

# Read from stdin
echo 'process = os.osc(440) : *(0.5);' | faust2ruby -e
```

### Ruby API

```ruby
require 'faust2ruby'

# Convert Faust to Ruby code
faust_code = 'process = os.osc(440) : *(0.5);'
ruby_code = Faust2Ruby.to_ruby(faust_code)

# Expression only
ruby_expr = Faust2Ruby.to_ruby(faust_code, expression_only: true)
# => "0.5 * osc(440)"
```

## Examples

### Simple Oscillator

```faust
process = os.osc(440) : *(0.5);
```
```ruby
0.5 * osc(440)
```

### Synthesizer with Controls

```faust
import("stdfaust.lib");
freq = hslider("freq", 440, 20, 20000, 1);
amp = hslider("amp", 0.5, 0, 1, 0.01);
process = os.osc(freq) : *(amp);
```
```ruby
freq = hslider("freq", init: 440, min: 20, max: 20000, step: 1)
amp = hslider("amp", init: 0.5, min: 0, max: 1, step: 0.01)
process = amp * osc(freq)
```

### Stereo Output

```faust
process = os.osc(440) , os.osc(880);
```
```ruby
osc(440) | osc(880)
```

### Feedback Delay

```faust
process = _ ~ (de.delay(44100, 22050) : *(0.5));
```
```ruby
wire ~ (0.5 * delay(44100, 22050))
```

### Iteration

```faust
process = par(i, 4, os.osc(i * 100));
```
```ruby
fpar(4) { |i| osc(i * 100) }
```

## Mapping Overview

### Composition

| Faust | Ruby |
|-------|------|
| `a : b` | `a >> b` |
| `a , b` | `a \| b` |
| `a <: b` | `a.split(b)` |
| `a :> b` | `a.merge(b)` |
| `a ~ b` | `a ~ b` |
| `*(x)` | `x *` (idiomatic) or `gain(x)` |

### Numeric Extensions

When arguments are numeric literals, faust2ruby emits idiomatic Ruby:

| Faust | Ruby |
|-------|------|
| `ba.db2linear(-6)` | `-6.db` |
| `ba.midikey2hz(60)` | `60.midi` |
| `ba.sec2samp(0.1)` | `0.1.sec` |

### Library Functions

Most `os.*`, `fi.*`, `de.*`, `en.*`, `ba.*`, `si.*`, `re.*`, `co.*`, `sp.*`, `aa.*`, `an.*`, `ef.*` functions are mapped. Examples:

- `os.osc(f)` → `osc(f)`
- `fi.lowpass(n, f)` → `lp(f, order: n)`
- `de.delay(m, d)` → `delay(m, d)`
- `en.adsr(a,d,s,r,g)` → `adsr(a, d, s, r, g)`
- `si.smoo` → `smoo`

### Primitives

| Faust | Ruby |
|-------|------|
| `_` | `wire` |
| `!` | `cut` |
| `mem` | `mem` |
| `ma.SR` | `sr` |

## Round-trip Conversion

```ruby
require 'frausto'

# Faust → Ruby → Faust
faust_input = 'process = os.osc(440) : *(0.5);'
ruby_expr = Faust2Ruby.to_ruby(faust_input, expression_only: true)

include Ruby2Faust::DSL
process = eval(ruby_expr)
faust_output = Ruby2Faust::Emitter.program(process)
```

## Advanced Features

### With Clauses

Local definitions are converted to Ruby lambdas:

```faust
myDSP = _ * gain with {
    gain = 0.5;
};
```
```ruby
myDSP = -> {
  gain = 0.5
  (wire * gain)
}.call
```

### Case Expressions

Faust's `case` creates a pattern-matching function—the `(n)` pattern binds the input signal to variable `n`:

```faust
process = case {
  (0) => 1;
  (1) => 2;
  (n) => n * 2;
};
```
```ruby
fcase(0 => 1, 1 => 2) { |n| (n * 2) }
```

The `fcase` DSL method handles integer patterns as a hash, with the block as the default case.

### Partial Application

```faust
halfGain = *(0.5);
process = osc(440) : halfGain;
```
```ruby
halfGain = gain(0.5)
process = osc(440) >> halfGain
```

## Limitations

**Not fully supported:**
- `letrec` blocks (emitted as `literal()`)
- Foreign functions (`ffunction`)
- Multi-parameter pattern matching
- Some library namespaces: `ve.*`, `pm.*`, `sy.*`, `dx.*`

Unmapped functions are preserved as `literal("...")` for round-trip compatibility.

## Architecture

```
Faust Source → Lexer → Parser → AST → Ruby Generator → Ruby DSL
```

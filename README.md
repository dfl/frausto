# Frausto

A Ruby toolkit for Faust DSP: generate Faust code from Ruby, or convert Faust to Ruby.

## Installation

```bash
gem install frausto
```

Or add to your Gemfile:

```ruby
gem 'frausto'
```

## Tools

- **[ruby2faust](ruby2faust.md)** - Ruby DSL that generates Faust DSP code
- **[faust2ruby](faust2ruby.md)** - Convert Faust DSP code to Ruby DSL

## Quick Example

```ruby
require 'ruby2faust'

code = Ruby2Faust.generate do
  osc(440) >> lp(800) >> gain(0.3)
end

puts code
# => import("stdfaust.lib");
#    process = (os.osc(440) : fi.lowpass(1, 800) : *(0.3));
```

```ruby
require 'faust2ruby'

ruby_code = Faust2Ruby.to_ruby('process = os.osc(440) : *(0.5);')
# => "osc(440) >> gain(0.5)"
```

## License

MIT

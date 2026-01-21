# Changelog

All notable changes to this project will be documented in this file.

## [0.2.2] - 2025-01-21

### Added
- `coerce` method on DSP class enabling numeric-on-left operations (`0.5 * osc(440)`)
- Numeric extensions in faust2ruby: `ba.db2linear(-6)` → `-6.db`, `ba.midikey2hz(60)` → `60.midi`, `ba.sec2samp(0.1)` → `0.1.sec`
- Precedence-aware parentheses in emitter - only adds parens when needed

### Changed
- ruby2faust now emits idiomatic Faust: `signal : *(scalar)` instead of `(signal * scalar)`
- ruby2faust now emits idiomatic Faust: `signal : /(scalar)` instead of `(signal / scalar)`
- faust2ruby now emits idiomatic Ruby: `scalar * signal` instead of `signal >> gain(scalar)`
- faust2ruby now emits idiomatic Ruby: `signal / scalar` instead of `signal >> literal("/(scalar)")`
- Cleaner output with minimal parentheses

### Fixed
- README examples updated to show improved output

## [0.2.1] - 2025-01-20

### Added
- Include .yardopts in gem

## [0.2.0] - 2025-01-20

### Added
- Initial release with ruby2faust and faust2ruby tools
- Ruby DSL for generating Faust DSP code
- Faust to Ruby converter
- Numeric extensions (.midi, .db, .sec, .ms, .hz)
- Pretty printing option
- CLI tools

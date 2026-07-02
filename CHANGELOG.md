# Changelog

## [0.2.1](https://github.com/GroupTherapyOrg/Therapy.jl/compare/v0.2.0...v0.2.1) (2026-07-02)


### Bug Fixes

* allow WasmTarget 0.4 (compat) ([401fbb4](https://github.com/GroupTherapyOrg/Therapy.jl/commit/401fbb427801d337eb13c4e5bc8cc0d69b8d0cb5))
* allow WasmTarget 0.4 (compat) ([cb38eb4](https://github.com/GroupTherapyOrg/Therapy.jl/commit/cb38eb47232e3a37689d1831b02bbf4e2005b9ff))

## [0.2.0](https://github.com/GroupTherapyOrg/Therapy.jl/compare/v0.1.2...v0.2.0) (2026-06-23)


### ⚠ BREAKING CHANGES

* HTTP.jl 1.x is no longer supported; embedders must upgrade to HTTP.jl >= 2.4.

### Features

* require HTTP.jl &gt;= 2.4 (security) + migrate server to HTTP 2.x stream API ([#9](https://github.com/GroupTherapyOrg/Therapy.jl/issues/9)) ([db1a9a7](https://github.com/GroupTherapyOrg/Therapy.jl/commit/db1a9a7d1f653d0b502e5ef0aab9bf53a26533b6))


### Bug Fixes

* opt wasm islands into js-string builtins + stub the io bridge ([6675b1b](https://github.com/GroupTherapyOrg/Therapy.jl/commit/6675b1b3f98b3de0077cecc74eb609f8c7b4cc55))
* opt wasm islands into js-string builtins + stub the io bridge ([ca3e267](https://github.com/GroupTherapyOrg/Therapy.jl/commit/ca3e2673b6dfe9c225e7cd1bf29c219c72dc1362))

## [0.1.2](https://github.com/GroupTherapyOrg/Therapy.jl/compare/v0.1.1...v0.1.2) (2026-06-11)


### Features

* WasmTarget 0.3 compat + Julia 1.13 support ([091d1cf](https://github.com/GroupTherapyOrg/Therapy.jl/commit/091d1cf98304cba8dce2c72e83f7c97936d65eb9))


### Bug Fixes

* drop accidental local-path [sources] entry for WasmTarget ([7c935b4](https://github.com/GroupTherapyOrg/Therapy.jl/commit/7c935b47a0cd2d036ba8eae7bc6d05b0d23a5f53))

## [0.1.1](https://github.com/GroupTherapyOrg/Therapy.jl/compare/v0.1.0...v0.1.1) (2026-06-10)


### Bug Fixes

* **deps:** bump WasmTarget compat to 0.2 ([d56afd6](https://github.com/GroupTherapyOrg/Therapy.jl/commit/d56afd6e0879305e39ffd708c6fca4f7706fc2b6))
* **deps:** bump WasmTarget compat to 0.2 (soundness + differential fuzzer release) ([aa6c300](https://github.com/GroupTherapyOrg/Therapy.jl/commit/aa6c3007654c1efd8eefc19a011eea14d2174e10))

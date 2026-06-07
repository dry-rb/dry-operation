# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

- `#step` now accepts an optional step name as its first argument (e.g. `step :validate, validate(input)`). When given, the name is forwarded to `#on_failure` via a new `step_name:` kwarg if the step fails, so a single `on_failure` hook can branch on which step failed. (@timriley in #42)
- `#on_failure` now supports `step_name:` and `method_name:` keyword arguments. Hooks can opt in to either or both — e.g. `def on_failure(failure, step_name:)`, `def on_failure(failure, method_name:)`, or `def on_failure(failure, step_name:, method_name:)`. The existing positional params signatures are unchanged: `def on_failure(failure)` and `def on_failure(failure, method_name)`. (@timriley in #42)

### Changed

- `#steps` now dispatches to `#on_failure` itself, so users who use `skip_prepending` and call `steps do ... end` manually get the same `#on_failure` routing as the auto-prepended case. Previously `#on_failure` only fired via the prepender. (@timriley in #42)
- The Validation extension forwards `:validation` via the `step_name:` kwarg to `#on_failure` when contract validation fails, so users can distinguish contract failures from other named steps. (@timriley in #42)

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/dry-rb/dry-operation/compare/v1.1.0...main

## [1.1.0] - 2026-02-06

### Changed

- In Rom extension, allow transaction options to be passed via `#transaction`. (@wuarmin in #37)
    ```ruby
    # Set options at extension time (used for all transactions within the class):
    include Dry::Operation::Extensions::ROM[isolation: :serializable]

    # Or per-transaction, in instance methods. These will be merged with the extension-level
    # options.
    transaction(savepoint: true) do
      # This transaction will have options `isolation: :serializable, savepoint: true`
    end
    ```

[1.1.0]: https://github.com/dry-rb/dry-operation/compare/v1.0.1...v1.1.0

## [1.0.1] - 2025-10-24

### Changed

- Define `#transaction` method in extension modules themselves (which are included into the operation class), rather than directly on the operation class itself. This adheres to typical Ruby inheritance-based method lookup, and allows for overloads of `#transaction` to be defined directly in the operation class or mixed in via other modules. (@timriley in #33)

[1.0.1]: https://github.com/dry-rb/dry-operation/compare/v1.0.0...v1.0.1

## 1.0.0 - 2024-11-02

### Added

- Initial release. (@waiting-for-dev)

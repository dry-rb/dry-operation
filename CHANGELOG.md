# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/dry-rb/dry-operation/compare/v1.2.0...main

## [1.2.0] - 2026-11-20

### Added

- Add a Validation extension, for validating operation input with Dry Validation. (@aaronmallen and @timriley in #34, #47)

    Define a contract with `params`, `schema`, or `contract`. The operation's keyword arguments are validated before the method runs, and the method receives the contract's output. If validation fails, the operation returns `Failure[:invalid, result]`.

    ```ruby
    class CreateUser < Dry::Operation
      include Dry::Operation::Extensions::Validation

      params do
        required(:name).filled(:string)
      end

      def call(name:)
        # ...
      end
    end
    ```

    By default, all keyword arguments are validated. Use `for:` to validate only one keyword argument, or `keys:` to validate a subset of them. All other keyword arguments are passed through untouched. Positional arguments are never validated.

    ```ruby
    params(for: :attrs) do
      required(:name).filled(:string)
    end

    params(keys: %i[account_id scope]) do
      required(:account_id).filled(:string)
      optional(:scope).array(:string)
    end
    ```

- `#step` now accepts any object that responds to `#to_result`, such as `Try`, `Maybe`, or `Validated` from Dry Monads. The object is converted to a result before it is processed. (@timriley in #38)

### Changed

- Require dry-monads 1.10 or later. This makes sure that dry-monads' RSpec extension is available for testing your operations. (@timriley in #45)
- Require Ruby 3.3 or later. (@timriley)

[1.2.0]: https://github.com/dry-rb/dry-operation/compare/v1.1.0...v1.2.0

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

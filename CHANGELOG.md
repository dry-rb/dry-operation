# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [1.0.1] - 2025-10-24

### Changed

- Define `#transaction` method in extension modules themselves (which are included into the operation class), rather than directly on the operation class itself. This adheres to typical Ruby inheritance-based method lookup, and allows for overloads of `#transaction` to be defined directly in the operation class or mixed in via other modules. (@timriley in #33)

## [1.0.0] - 2024-11-02

### Added

- Initial release. (@waiting-for-dev)

[1.0.1]: https://github.com/dry-rb/dry-operation/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dry-rb/dry-operation/releases/tag/v1.0.0

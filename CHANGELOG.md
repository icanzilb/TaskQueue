# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased](https://github.com/icanzilb/TaskQueue/compare/1.1.1...HEAD)

## [1.1.1](https://github.com/icanzilb/TaskQueue/compare/1.1.0...1.1.1) - 2018-04-04

### Changed

- Set macOS miniumum deployment target to 10.10

## [1.1.0](https://github.com/icanzilb/TaskQueue/compare/1.0.1...1.1.0) - 2018-03-22

### Changed

- Updated to use Swift 4
- `APPLICATION_EXTENSION_API_ONLY` set to `YES`
- Set iOS miniumum deployment target to 8.0
- Use `Sources` and `Tests` directories to match current coventions
- Single target and scheme for iOS, macOS, and tvOS builds

### Added

- Carthage support for macOS and tvOS
- `pauseAndResetCurrentTask` to pause the queue and reset the running task, if any

## [1.0.1](https://github.com/icanzilb/TaskQueue/compare/0.9.10...1.0.1) - 2016-10-14

### Changed

- Updated to use Swift 3
- Updated to work with Xcode 8

## [0.9.10](https://github.com/icanzilb/TaskQueue/compare/0.9.9...0.9.10) - 2016-04-12

### Fixed

- Made init public

## [0.9.9](https://github.com/icanzilb/TaskQueue/compare/0.9.8...0.9.9) - 2016-04-08

### Added

- Carthage support

### Changed

- Updated to use Swift 2.2
- Updated to work with Xcode 7.3

## [0.9.8](https://github.com/icanzilb/TaskQueue/compare/0.9.7...0.9.8) - 2015-09-21

### Changed

- Updated to use Swift 2

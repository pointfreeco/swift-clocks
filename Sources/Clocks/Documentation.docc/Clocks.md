# ``Clocks``

A few clocks that make working with Swift concurrency more testable and more versatile.

## Overview

The `Clock` protocol in provides a powerful abstraction for time-based asynchrony in Swift's
structured concurrency. With just a single `sleep` method you can express many powerful async
operators, such as timers, `debounce`, `throttle`, `timeout` and more (see
[swift-async-algorithms][swift-async-algorithms]).

However, the moment you use a concrete clock in your asynchronous code, or use `Task.sleep`
directly, you instantly lose the ability to easily test and preview your features, forcing you to
wait for real world time to pass to see how your feature works.

This library provides new `Clock` conformances (``TestClock``, ``ImmediateClock`` and
``UnimplementedClock``) that allow you to turn any time-based asynchronous code into something that
is easier to test and debug.

## Topics

### Implementations

- ``ImmediateClock``
- ``TestClock``
- ``UnimplementedClock``

### Concrete erasure

- ``AnyClock``

[swift-async-algorithms]: http://github.com/apple/swift-async-algorithms

# swift-clocks

[![CI](https://github.com/pointfreeco/swift-clocks/workflows/CI/badge.svg)](https://github.com/pointfreeco/swift-clocks/actions?query=workflow%3ACI)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpointfreeco%2Fswift-clocks%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/pointfreeco/swift-clocks)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpointfreeco%2Fswift-clocks%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/pointfreeco/swift-clocks)

⏰ A few clocks that make working with Swift concurrency more testable and more versatile.

* [Motivation](#motivation)
* [Learn more](#learn-more)
  * [`TestClock`](#testclock)
  * [`ImmediateClock`](#immediateclock)
  * [`UnimplementedClock`](#unimplementedclock)
  * [Timers](#timers)
  * [`AnyClock`](#anyclock)
* [Documentation](#documentation)
* [License](#License)

## Learn More

This library was designed in episodes on [Point-Free][point-free], a video series exploring the
Swift programming language hosted by [Brandon Williams][mbrandonw] and
[Stephen Celis][stephencelis].

You can watch all of the episodes [here][clock-collection].

<a href="https://www.pointfree.co/collections/concurrency/clocks">
  <img alt="video poster image" src="https://i.vimeocdn.com/video/1524033919-5201b27e94ead2d18805eae70faf0282028d27c926bfaa5423d9d28fa1f72301-d" width="480">
</a>

## Motivation

The `Clock` protocol in Swift provides a powerful abstraction for time-based asynchrony in Swift's
structured concurrency. With just a single `sleep` method you can express many powerful async
operators, such as timers, `debounce`, `throttle`, `timeout` and more (see
[swift-async-algorithms][swift-async-algorithms]).

However, the moment you use a concrete clock in your asynchronous code, or use `Task.sleep`
directly, you instantly lose the  ability to easily test and preview your features, forcing you to
wait for real world time to pass to see how your feature works.

This library provides new `Clock` conformances that allow you to turn any time-based asynchronous
code into something that is easier to test and debug:

* [`TestClock`](#TestClock)
* [`ImmediateClock`](#ImmediateClock)
* [`UnimplementedClock`](#UnimplementedClock)
* [Timers](#Timers)
* [`AnyClock`](#AnyClock)

### `TestClock`

A clock whose time can be controlled in a deterministic manner.

This clock is useful for testing how the flow of time affects asynchronous and concurrent code.
This includes any code that makes use of `sleep` or any time-based async operators, such as
`debounce`, `throttle`, `timeout`, and more.

For example, suppose you have a model that encapsulates the behavior of a timer that be started and
stopped, and with each tick of the timer a count value was incremented:

```swift
@MainActor
class FeatureModel: ObservableObject {
  @Published var count = 0
  let clock: any Clock<Duration>
  var timerTask: Task<Void, Error>?

  init(clock: any Clock<Duration>) {
    self.clock = clock
  }
  func startTimerButtonTapped() {
    self.timerTask = Task {
      while true {
        try await self.clock.sleep(for: .seconds(1))
        self.count += 1
      }
    }
  }
  func stopTimerButtonTapped() {
    self.timerTask?.cancel()
    self.timerTask = nil
  }
}
```

Note that we have explicitly forced a clock to be provided in order to construct the `FeatureModel`.
This makes it possible to use a real life clock, such as `ContinuousClock`, when running on a device
or simulator, and use a more controllable clock in tests, such as the 
[`TestClock`][test-clock-docs].

To write a test for this feature we can construct a `FeatureModel` with a `TestClock`, then advance
the clock forward and assert on how the model changes:

```swift
func testTimer() async {
  let clock = TestClock()
  let model = FeatureModel(clock: clock)

  XCTAssertEqual(model.count, 0)
  model.startTimerButtonTapped()

  // Advance the clock 1 second and prove that the model's
  // count incremented by one.
  await clock.advance(by: .seconds(1))
  XCTAssertEqual(model.count, 1)

  // Advance the clock 4 seconds and prove that the model's
  // count incremented by 4.
  await clock.advance(by: .seconds(4))
  XCTAssertEqual(model.count, 5)

  // Stop the timer, run the clock until there is no more
  // suspensions, and prove that the count did not increment.
  model.stopTimerButtonTapped()
  await clock.run()
  XCTAssertEqual(model.count, 5)
}
```

This test is easy to write, passes deterministically, and takes a fraction of a second to run. If
you were to use a concrete clock in your feature, such a test would be difficult to write. You
would have to wait for real time to pass, slowing down your test suite, and you would have to take
extra care to allow for the inherent imprecision in time-based asynchrony so that you do not have
flakey tests.

### `ImmediateClock`

A clock that does not suspend when sleeping.

This clock is useful for squashing all of time down to a single instant, forcing any `sleep`s to
execute immediately. For example, suppose you have a feature that needs to wait 5 seconds before
performing some action, like showing a welcome message:

```swift
struct Feature: View {
  @State var message: String?

  var body: some View {
    VStack {
      if let message = self.message {
        Text(self.message)
      }
    }
    .task {
      do {
        try await Task.sleep(for: .seconds(5))
        self.message = "Welcome!"
      } catch {}
    }
  }
}
```

This is currently using a real life clock by calling out to `Task.sleep`, which means every change
you make to the styling and behavior of this feature you must wait for 5 real life seconds to pass
before you see the effect. This will severely hurt you ability to quickly iterate on the feature in
an Xcode preview.

The fix is to have your view hold onto a clock so that it can be controlled from the outside:

```swift
struct Feature: View {
  @State var message: String?
  let clock: any Clock<Duration>

  var body: some View {
    VStack {
      if let message = self.message {
        Text(self.message)
      }
    }
    .task {
      do {
        try await self.clock.sleep(for: .seconds(5))
        self.message = "Welcome!"
      } catch {}
    }
  }
}
```

Then you can construct this view with a `ContinuousClock` when running on a device or simulator,
and use an ``ImmediateClock`` when running in an Xcode preview:

```swift
struct Feature_Previews: PreviewProvider {
  static var previews: some View {
    Feature(clock: ImmediateClock())
  }
}
```

Now the welcome message will be displayed immediately with every change made to the view. No
need to wait for 5 real world seconds to pass.

You can also propagate a clock to a SwiftUI view via the `continuousClock` and `suspendingClock`
environment values that ship with the library:

```swift
struct Feature: View {
  @State var message: String?
  @Environment(\.continuousClock) var clock

  var body: some View {
    VStack {
      if let message = self.message {
        Text(self.message)
      }
    }
    .task {
      do {
        try await self.clock.sleep(for: .seconds(5))
        self.message = "Welcome!"
      } catch {}
    }
  }
}

struct Feature_Previews: PreviewProvider {
  static var previews: some View {
    Feature()
      .environment(\.continuousClock, ImmediateClock())
  }
}
```

### `UnimplementedClock`

A clock that causes an XCTest failure when any of its endpoints are invoked.

This clock is useful when a clock dependency must be provided to test a feature, but you don't
actually expect the clock to be used in the particular execution flow you are exercising.

For example, consider the following model that encapsulates the behavior of being able to increment
and decrement a count, as well as starting and stopping a timer that increments the counter every
second:

```swift
@MainActor
class FeatureModel: ObservableObject {
  @Published var count = 0
  let clock: any Clock<Duration>
  var timerTask: Task<Void, Error>?

  init(clock: some Clock<Duration>) {
    self.clock = clock
  }
  func incrementButtonTapped() {
    self.count += 1
  }
  func decrementButtonTapped() {
    self.count -= 1
  }
  func startTimerButtonTapped() {
    self.timerTask = Task {
      for await _ in self.clock.timer(interval: .seconds(1)) {
        self.count += 1
      }
    }
  }
  func stopTimerButtonTapped() {
    self.timerTask?.cancel()
    self.timerTask = nil
  }
}
```

If we test the flow of the user incrementing and decrementing the count, there is no need for the
clock. We don't expect any time-based asynchrony to occur. To make this clear, we can use an
`UnimplementedClock`:

```swift
func testIncrementDecrement() {
  let model = FeatureModel(clock: UnimplementedClock())

  XCTAssertEqual(model.count, 0)
  self.model.incrementButtonTapped()
  XCTAssertEqual(model.count, 1)
  self.model.decrementButtonTapped()
  XCTAssertEqual(model.count, 0)
}
```

If this test passes it definitively proves that the clock is not used at all in the user flow being
tested, making this test stronger. If in the future the increment and decrement endpoints start
making use of time-based asynchrony using the clock, we will be instantly notified by test failures.
This will help us find the tests that should be updated to assert on the new behavior in the
feature.

### Timers

All clocks now come with a method that allows you to create an `AsyncSequence`-based timer on an
interval specified by a duration. This allows you to handle timers with simple `for await` syntax,
such as this observable object that exposes the ability to start and stop a timer for incrementing a
value every second:

```swift
@MainActor
class FeatureModel: ObservableObject {
  @Published var count = 0
  let clock: any Clock<Duration>
  var timerTask: Task<Void, Error>?

  init(clock: any Clock<Duration>) {
    self.clock = clock
  }
  func startTimerButtonTapped() {
    self.timerTask = Task {
      for await _ in self.clock.timer(interval: .seconds(1)) {
        self.count += 1
      }
    }
  }
  func stopTimerButtonTapped() {
    self.timerTask?.cancel()
    self.timerTask = nil
  }
}
```

This feature can also be easily tested by making use of the `TestClock` discussed above:

```swift
func testTimer() async {
  let clock = TestClock()
  let model = FeatureModel(clock: clock)

  XCTAssertEqual(model.count, 0)
  model.startTimerButtonTapped()

  await clock.advance(by: .seconds(1))
  XCTAssertEqual(model.count, 1)

  await clock.advance(by: .seconds(4))
  XCTAssertEqual(model.count, 5)

  model.stopTimerButtonTapped()
  await clock.run()
}
```

### `AnyClock`

A concrete version of `any Clock`.

This type makes it possible to pass clock existentials to APIs that would otherwise prohibit it.

For example, the [Async Algorithms](https://github.com/apple/swift-async-algorithms) package
provides a number of APIs that take clocks, but due to limitations in Swift, they cannot take a
clock existential of the form `any Clock`:

```swift
class Model: ObservableObject {
  let clock: any Clock<Duration>
  init(clock: some Clock<Duration>) {
    self.clock = clock
  }

  func task() async {
    // 🛑 Type 'any Clock<Duration>' cannot conform to 'Clock'
    for await _ in stream.debounce(for: .seconds(1), clock: self.clock) {
      // ...
    }
  }
}
```

By using a concrete `AnyClock`, instead, we can work around this limitation:

```swift
// ✅
for await _ in stream.debounce(for: .seconds(1), clock: AnyClock(self.clock)) {
  // ...
}
```

## Documentation

The latest documentation for this library is available [here][clock-docs].

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-async-algorithms]: http://github.com/apple/swift-async-algorithms
[point-free]: https://www.pointfree.co
[mbrandonw]: https://github.com/mbrandonw
[stephencelis]: https://github.com/stephencelis
[clock-collection]: https://www.pointfree.co/collections/concurrency/clocks
[clock-docs]: https://swiftpackageindex.com/pointfreeco/swift-clocks/main/documentation/clocks
[test-clock-docs]: todo

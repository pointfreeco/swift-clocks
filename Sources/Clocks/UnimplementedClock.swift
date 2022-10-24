#if swift(>=5.7) && (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  import Foundation
  import XCTestDynamicOverlay

  /// A clock that causes an XCTest failure when any of its endpoints are invoked.
  ///
  /// This test is useful when a clock dependency must be provided to test a feature, but you don't
  /// actually expect time-based asynchrony to occur in the particular execution flow you are
  /// exercising.
  ///
  /// For example, consider the following model that encapsulates the behavior of being able to
  /// increment and decrement a count, as well as starting and stopping a timer that increments
  /// the counter every second:
  ///
  /// ```swift
  /// @MainActor
  /// class FeatureModel: ObservableObject {
  ///   @Published var count = 0
  ///   let clock: any Clock<Duration>
  ///   var timerTask: Task<Void, Error>?
  ///
  ///   init(clock: any Clock<Duration>) {
  ///     self.clock = clock
  ///   }
  ///   func incrementButtonTapped() {
  ///     self.count += 1
  ///   }
  ///   func decrementButtonTapped() {
  ///     self.count -= 1
  ///   }
  ///   func startTimerButtonTapped() {
  ///     self.timerTask = Task {
  ///       for await _ in self.clock.timer(interval: .seconds(5)) {
  ///         self.count += 1
  ///       }
  ///     }
  ///   }
  ///   func stopTimerButtonTapped() {
  ///     self.timerTask?.cancel()
  ///     self.timerTask = nil
  ///   }
  /// }
  /// ```
  ///
  /// If we test the flow of the user incrementing and decrementing the count, there is no need for
  /// the clock. We don't expect any time-based asynchrony to occur. To make this clear, we can
  /// use an ``UnimplementedClock``:
  ///
  /// ```swift
  /// func testIncrementDecrement() {
  ///   let model = FeatureModel(clock: .unimplemented)
  ///
  ///   XCTAssertEqual(model.count, 0)
  ///   self.model.incrementButtonTapped()
  ///   XCTAssertEqual(model.count, 1)
  ///   self.model.decrementButtonTapped()
  ///   XCTAssertEqual(model.count, 0)
  /// }
  /// ```
  ///
  /// If this test passes it definitively proves that the clock is not used at all in the user flow
  /// being tested, making this test stronger. If in the future the increment and decrement endpoints
  /// start making use of time-based asynchrony using the clock, we will be instantly notified by test
  /// failures. This will help us find the tests that should be updated to assert on the new behavior
  /// in the feature.
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public final class UnimplementedClock<Duration>: Clock, @unchecked Sendable
  where
    Duration: DurationProtocol,
    Duration: Hashable
  {
    public struct Instant: InstantProtocol {
      public var offset: Duration
      public init(offset: Duration = .zero) {
        self.offset = offset
      }

      public func advanced(by duration: Duration) -> Self {
        .init(offset: self.offset + duration)
      }

      public func duration(to other: Self) -> Duration {
        other.offset - self.offset
      }

      public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.offset < rhs.offset
      }
    }

    public var now: Instant {
      XCTFail("Unimplemented: \(self.name).now")
      return self._now
    }
    public var _now = Instant()
    public var minimumResolution: Duration {
      XCTFail("Unimplemented: \(self.name).minimumResolution")
      return .zero
    }
    /// The name of the clock.
    ///
    /// Printed to identify the clock in failure messages.
    public let name: String

    private let lock = NSRecursiveLock()

    public init(
      name: String = "Clock",
      now: Instant = .init()
    ) {
      self.name = name
      self._now = now
    }

    public func sleep(until deadline: Instant, tolerance: Instant.Duration? = nil) async throws {
      XCTFail("Unimplemented: \(self.name).sleep")
      try Task.checkCancellation()
      self.lock.sync { self._now = deadline }
      await Task.megaYield()
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension UnimplementedClock where Duration == Swift.Duration {
    public convenience init(name: String = "Clock") {
      self.init(name: name, now: .init())
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Clock where Self == UnimplementedClock<Swift.Duration> {
    /// A clock that causes an XCTest failure when any of its endpoints are invoked.
    ///
    /// Constructs and returns an ``UnimplementedClock``
    ///
    /// > Important: Due to [a bug in Swift](https://github.com/apple/swift/issues/61645), this static
    /// > value cannot be used in an existential context:
    /// >
    /// > ```swift
    /// > let clock: any Clock<Duration> = .unimplemented  // 🛑
    /// > ```
    /// >
    /// > To work around this bug, construct an unimplemented clock directly:
    /// >
    /// > ```swift
    /// > let clock: any Clock<Duration> = UnimplementedClock()  // ✅
    /// > ```
    public static var unimplemented: Self {
      UnimplementedClock()
    }
  }
#endif

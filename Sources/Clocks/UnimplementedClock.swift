#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  import ConcurrencyExtras
  import Foundation
  import IssueReporting

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
  ///   init(clock: some Clock<Duration>) {
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
  public struct UnimplementedClock<Duration: DurationProtocol & Hashable>: Clock {
    public struct Instant: InstantProtocol {
      fileprivate let rawValue: AnyClock<Duration>.Instant

      public func advanced(by duration: Duration) -> Self {
        Self(rawValue: self.rawValue.advanced(by: duration))
      }

      public func duration(to other: Self) -> Duration {
        self.rawValue.duration(to: other.rawValue)
      }

      public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
      }
    }

    private let base: AnyClock<Duration>
    private let name: String
    private let fileID: StaticString
    private let filePath: StaticString
    private let line: UInt
    private let column: UInt

    public init<C: Clock>(
      _ base: C,
      name: String = "\(C.self)",
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) where C.Duration == Duration {
      self.base = AnyClock(base)
      self.name = name
      self.fileID = fileID
      self.filePath = filePath
      self.line = line
      self.column = column
    }

    public init(
      name: String = "Clock",
      now: ImmediateClock<Duration>.Instant = .init(),
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) {
      self.init(
        ImmediateClock(now: now),
        name: name,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    }

    public var now: Instant {
      reportIssue(
        "Unimplemented: \(self.name).now",
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return Instant(rawValue: self.base.now)
    }

    public var minimumResolution: Duration {
      reportIssue(
        "Unimplemented: \(self.name).minimumResolution",
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return self.base.minimumResolution
    }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
      reportIssue(
        "Unimplemented: \(self.name).sleep",
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      try await self.base.sleep(until: deadline.rawValue, tolerance: tolerance)
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension UnimplementedClock where Duration == Swift.Duration {
    public init(name: String = "Clock") {
      self.init(name: name, now: .init())
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Clock where Self == UnimplementedClock<Swift.Duration> {
    /// A clock that causes an XCTest failure when any of its endpoints are invoked.
    ///
    /// Constructs and returns an ``UnimplementedClock``
    ///
    /// > Important: Due to [a bug in Swift <6](https://github.com/apple/swift/issues/61645), this
    /// > static value cannot be used in an existential context:
    /// >
    /// > ```swift
    /// > let clock: any Clock<Duration> = .unimplemented()  // 🛑
    /// > ```
    /// >
    /// > To work around this bug, construct an unimplemented clock directly:
    /// >
    /// > ```swift
    /// > let clock: any Clock<Duration> = UnimplementedClock()  // ✅
    /// > ```
    public static func unimplemented(
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) -> Self {
      UnimplementedClock(fileID: fileID, filePath: filePath, line: line, column: column)
    }
  }
#endif

#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  /// A type-erased clock.
  ///
  /// This type provides a concrete alternative to `any Clock<Duration>` and makes it possible to
  /// pass clock existentials to APIs that would otherwise prohibit it.
  ///
  /// For example, the [Async Algorithms](https://github.com/apple/swift-async-algorithms) package
  /// provides a number of APIs that take clocks, but due to limitations in Swift, they cannot take
  /// a clock existential of the form `any Clock`:
  ///
  /// ```swift
  /// class Model: ObservableObject {
  ///   let clock: any Clock<Duration>
  ///   init(clock: some Clock<Duration>) {
  ///     self.clock = clock
  ///   }
  ///
  ///   func task() async {
  ///     // 🛑 Type 'any Clock<Duration>' cannot conform to 'Clock'
  ///     for await _ in stream.debounce(for: .seconds(1), clock: self.clock) {
  ///       // ...
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// By using a concrete `AnyClock`, instead, we can work around this limitation:
  ///
  /// ```swift
  /// // ✅
  /// for await _ in stream.debounce(for: .seconds(1), clock: AnyClock(self.clock)) {
  ///   // ...
  /// }
  /// ```
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public final class AnyClock<Duration: DurationProtocol & Hashable>: NonsendingClock {
    public struct Instant: InstantProtocol {
      fileprivate let offset: Duration

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

    private let _minimumResolution: @Sendable () -> Duration
    private let _now: @Sendable () -> Instant
    private let _sleep: @Sendable (Instant, Duration?, isolated (any Actor)?) async throws -> Void

    public init<C: Clock>(_ clock: C) where C.Instant.Duration == Duration {
      let start = clock.now
      self._now = { Instant(offset: start.duration(to: clock.now)) }
      self._minimumResolution = { clock.minimumResolution }
      self._sleep = { deadline, tolerance, _ in
        try await clock.sleep(
          until: start.advanced(by: deadline.offset),
          tolerance: tolerance
        )
      }
    }

    #if compiler(>=6.2)
      public init<C: NonsendingClock>(_ clock: C)
      where C.Instant.Duration == Duration {
        let start = clock.now
        self._now = { Instant(offset: start.duration(to: clock.now)) }
        self._minimumResolution = { clock.minimumResolution }
        self._sleep = { deadline, tolerance, isolation in
          try await clock.sleep(
            until: start.advanced(by: deadline.offset),
            tolerance: tolerance,
            isolation: isolation
          )
        }
      }
    #endif

    public var minimumResolution: Duration {
      self._minimumResolution()
    }

    public var now: Instant {
      self._now()
    }

    nonisolated(nonsending)
      public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws
    {
      try await self.sleep(
        until: deadline,
        tolerance: tolerance,
        isolation: #isolation
      )
    }

    #if compiler(>=6.2)
      public func sleep(
        until deadline: Instant,
        tolerance: Duration? = nil,
        isolation: isolated (any Actor)?
      ) async throws {
        try await self._sleep(deadline, tolerance, isolation)
      }
    #endif
  }
#endif

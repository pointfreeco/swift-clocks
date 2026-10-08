#if compiler(>=6.2)
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public protocol NonsendingClock<Duration>: Clock {
    func sleep(
      until deadline: Instant,
      tolerance: Instant.Duration?,
      isolation: isolated (any Actor)?
    ) async throws
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension NonsendingClock {
    public func sleep(
      until deadline: Instant,
      tolerance: Instant.Duration?,
      isolation: isolated (any Actor)? = #isolation
    ) async throws {
      try await sleep(until: deadline, tolerance: tolerance)
    }

    nonisolated(nonsending)
      public func sleep(for duration: Duration, tolerance: Instant.Duration? = nil) async throws
    {
      try await sleep(
        until: now.advanced(by: duration),
        tolerance: tolerance,
        isolation: #isolation
      )
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension AnyClock: NonsendingClock {}

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension ContinuousClock: NonsendingClock {}

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension ImmediateClock: NonsendingClock {}

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension SuspendingClock: NonsendingClock {}

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension TestClock: NonsendingClock {}

  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  extension TestClock2: NonsendingClock {}

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension UnimplementedClock: NonsendingClock {}
#endif

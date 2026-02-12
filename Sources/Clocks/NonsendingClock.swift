#if compiler(>=6.2)
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public protocol NonsendingClock<Duration>: Clock {
    nonisolated(nonsending)
      func sleep(until deadline: Instant, tolerance: Instant.Duration?) async throws
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension NonsendingClock {
    nonisolated(nonsending)
      public func sleep(for duration: Duration, tolerance: Instant.Duration? = nil) async throws
    {
      try await sleep(until: now.advanced(by: duration), tolerance: tolerance)
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
#endif

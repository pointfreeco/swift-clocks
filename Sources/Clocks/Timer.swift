#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Clock where Duration: Hashable {
    /// Creates an async sequence that emits the clock's `now` value on an interval.
    public func timer(
      interval: Self.Duration,
      tolerance: Self.Duration? = nil
    ) -> _AsyncTimerSequence<AnyClock<Duration>> {
      .init(interval: interval, tolerance: tolerance, clock: AnyClock(self))
    }
  }
#endif

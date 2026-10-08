#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Clock where Duration: Hashable {
    public func timer(
      interval: Self.Duration,
      tolerance: Self.Duration? = nil
    ) -> _AsyncTimerSequence<AnyClock<Duration>> {
      .init(interval: interval, tolerance: tolerance, clock: AnyClock(self))
    }
  }

  #if compiler(>=6.2)
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    extension NonsendingClock where Duration: Hashable {
      public func timer(
        interval: Self.Duration,
        tolerance: Self.Duration? = nil
      ) -> _AsyncTimerSequence<AnyClock<Duration>> {
        .init(interval: interval, tolerance: tolerance, clock: AnyClock(nonsending: self))
      }
    }
  #endif
#endif

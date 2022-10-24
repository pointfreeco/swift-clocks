#if swift(>=5.7) && (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Clock {
    /// Suspends for the given duration.
    ///
    /// This method should be provided by the standard library, but it is not yet included. See this
    /// proposal for more information:
    /// <https://github.com/apple/swift-evolution/blob/main/proposals/0374-clock-sleep-for.md>
    @_disfavoredOverload
    public func sleep(
      for duration: Duration,
      tolerance: Duration? = nil
    ) async throws {
      try await self.sleep(until: self.now.advanced(by: duration), tolerance: tolerance)
    }
  }
#endif

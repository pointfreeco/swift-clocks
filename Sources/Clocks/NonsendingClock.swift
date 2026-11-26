/// A mechanism in which to measure time, and delay work until a given point in time.
///
/// The protocol extends the standard library `Clock` protocol to make it "nonsending". That is,
/// when `sleep` is called it will invoke the caller's isolation rather than hopping to the
/// global concurrent executor. Nonsending clocks are essential for writing testable code involving
/// time-based asynchrony.
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public protocol NonsendingClock<Duration>: Clock {
  @_nonoverride
  func sleep(until deadline: Instant, tolerance: Instant.Duration?) async throws
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NonsendingClock {
  public func sleep(for duration: Duration, tolerance: Instant.Duration? = nil) async throws {
    try await sleep(until: now.advanced(by: duration), tolerance: tolerance)
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension ContinuousClock: NonsendingClock {}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension SuspendingClock: NonsendingClock {}

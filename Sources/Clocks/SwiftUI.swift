#if canImport(SwiftUI)
  public import SwiftUI

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  extension EnvironmentValues {
    @Entry
    public var continuousClock: any NonsendingClock<Duration> = ContinuousClock()
    @Entry
    public var suspendingClock: any NonsendingClock<Duration> = SuspendingClock()
  }
#endif

#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst)) && canImport(SwiftUI)
  public import SwiftUI

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  extension EnvironmentValues {
    public var continuousClock: any NonsendingClock<Duration> {
      get { self[ContinuousClockKey.self] }
      set { self[ContinuousClockKey.self] = newValue }
    }

    public var suspendingClock: any NonsendingClock<Duration> {
      get { self[SuspendingClockKey.self] }
      set { self[SuspendingClockKey.self] = newValue }
    }
  }

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private enum ContinuousClockKey: EnvironmentKey {
    static let defaultValue: any NonsendingClock<Duration> = ContinuousClock()
  }

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private enum SuspendingClockKey: EnvironmentKey {
    static let defaultValue: any NonsendingClock<Duration> = SuspendingClock()
  }
#endif

#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst)) && canImport(SwiftUI)
  import SwiftUI

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  extension EnvironmentValues {
    public var continuousClock: any Clock<Duration> {
      get { self[ContinuousClockKey.self] }
      set { self[ContinuousClockKey.self] = newValue }
    }

    public var suspendingClock: any Clock<Duration> {
      get { self[SuspendingClockKey.self] }
      set { self[SuspendingClockKey.self] = newValue }
    }
  }

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private enum ContinuousClockKey: EnvironmentKey {
    static let defaultValue: any Clock<Duration> = ContinuousClock()
  }

  @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
  private enum SuspendingClockKey: EnvironmentKey {
    static let defaultValue: any Clock<Duration> = SuspendingClock()
  }
#endif

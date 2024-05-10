#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  import ConcurrencyExtras
  import Foundation

  /// A clock that does not suspend when sleeping.
  ///
  /// This clock is useful for squashing all of time down to a single instant, forcing any `sleep`s
  /// to execute immediately.
  ///
  /// For example, suppose you have a feature that needs to wait 5 seconds before performing some
  /// action, like showing a welcome message:
  ///
  /// ```swift
  /// struct Feature: View {
  ///   @State var message: String?
  ///
  ///   var body: some View {
  ///     VStack {
  ///       if let message = self.message {
  ///         Text(self.message)
  ///           .font(.largeTitle.bold())
  ///           .foregroundColor(.mint)
  ///       }
  ///     }
  ///     .task {
  ///       do {
  ///         try await Task.sleep(for: .seconds(5))
  ///         self.message = "Welcome!"
  ///       } catch {}
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// This is currently using a real life clock by calling out to `Task.sleep(for:)`, which means
  /// every change you make to the styling and behavior of this feature you must wait for 5 real life
  /// seconds to pass before you see the affect. This will severely hurt your ability to quickly
  /// iterate on the feature in an Xcode preview.
  ///
  /// The fix is to have your view hold onto a clock so that it can be controlled from the outside:
  ///
  /// ```swift
  /// struct Feature: View {
  ///   @State var message: String?
  ///   let clock: any Clock<Duration>
  ///
  ///   var body: some View {
  ///     VStack {
  ///       if let message = self.message {
  ///         Text(self.message)
  ///           .font(.largeTitle.bold())
  ///           .foregroundColor(.mint)
  ///       }
  ///     }
  ///     .task {
  ///       do {
  ///         try await self.clock.sleep(for: .seconds(5))
  ///         self.message = "Welcome!"
  ///       } catch {}
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// This code is nearly the same as before except that it now holds onto an explicit clock. This
  /// allows you to use a `ContinuousClock` when running on a device or simulator, and use an
  /// ``ImmediateClock`` when running in an Xcode preview:
  ///
  /// ```swift
  /// struct Feature_Previews: PreviewProvider {
  ///   static var previews: some View {
  ///     Feature(clock: .immediate)
  ///   }
  /// }
  /// ```
  ///
  /// Now the welcome message will be displayed immediately with every change made to the view. No
  /// need to wait for 5 real world seconds to pass, making it easier to iterate on the feature.
  ///
  /// You can also propagate a clock to a SwiftUI view via the `continuousClock` and `suspendingClock`
  /// environment values that ship with the library:
  ///
  /// ```swift
  /// struct Feature: View {
  ///   @State var message: String?
  ///   @Environment(\.continuousClock) var clock
  ///
  ///   var body: some View {
  ///     VStack {
  ///       if let message = self.message {
  ///         Text(self.message)
  ///       }
  ///     }
  ///     .task {
  ///       do {
  ///         try await self.clock.sleep(for: .seconds(5))
  ///         self.message = "Welcome!"
  ///       } catch {}
  ///     }
  ///   }
  /// }
  ///
  /// struct Feature_Previews: PreviewProvider {
  ///   static var previews: some View {
  ///     Feature()
  ///       .environment(\.continuousClock, .immediate)
  ///   }
  /// }
  /// ```
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public final class ImmediateClock<Duration>: Clock, @unchecked Sendable
  where
    Duration: DurationProtocol,
    Duration: Hashable
  {
    public struct Instant: InstantProtocol {
      fileprivate let offset: Duration

      public init(offset: Duration = .zero) {
        self.offset = offset
      }

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

    public private(set) var now: Instant
    public private(set) var minimumResolution: Duration = .zero
    private let lock = NSLock()

    public init(now: Instant = .init()) {
      self.now = now
    }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
      try Task.checkCancellation()
      self.lock.sync { self.now = deadline }
      await Task.megaYield()
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension ImmediateClock where Duration == Swift.Duration {
    public convenience init() {
      self.init(now: .init())
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension Clock where Self == ImmediateClock<Swift.Duration> {
    /// A clock that does not suspend when sleeping.
    ///
    /// Constructs and returns an ``ImmediateClock``
    ///
    /// > Important: Due to [a bug in Swift](https://github.com/apple/swift/issues/61645), this static
    /// > value cannot be used in an existential context:
    /// >
    /// > ```swift
    /// > let clock: any Clock<Duration> = .immediate  // 🛑
    /// > ```
    /// >
    /// > To work around this bug, construct an immediate clock directly:
    /// >
    /// > ```swift
    /// > let clock: any Clock<Duration> = ImmediateClock()  // ✅
    /// > ```
    public static var immediate: Self {
      ImmediateClock()
    }
  }
#endif

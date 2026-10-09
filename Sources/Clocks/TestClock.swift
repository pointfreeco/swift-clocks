import IssueReporting

/// A clock whose time can be controlled in a deterministic manner.
///
/// This clock is useful for testing how the flow of time affects asynchronous and concurrent code.
/// This includes any code that makes use of `sleep` or any time-based async operators, such as
/// timers, `debounce`, `throttle`, `timeout`, and more.
///
/// For example, suppose you have a model that encapsulates the behavior of a timer that can be
/// started and stopped:
///
/// ```swift
/// @MainActor
/// @Observable
/// final class FeatureModel {
///   var count = 0
///   let clock: any NonsendingClock<Duration>
///   var timerTask: Task<Void, Error>?
///
///   init(clock: any Clock<Duration>) {
///     self.clock = clock
///   }
///   func startTimerButtonTapped() {
///     timerTask = Task {
///       while true {
///         try await self.clock.sleep(for: .seconds(1))
///         count += 1
///       }
///     }
///   }
///   func stopTimerButtonTapped() {
///     timerTask?.cancel()
///     timerTask = nil
///   }
/// }
/// ```
///
/// > Note: In order to allow clocks to be deterministically testable you must use the
/// > ``NonsendingClock`` protocol instead of the `Clock` protocol.
///
/// Here we have explicitly forced a clock to be provided in order to construct the `FeatureModel`.
/// This makes it possible to use a real life clock, such as `ContinuousClock`, when running on a
/// device or simulator, and use a more controllable clock in tests, such as the ``TestClock``
/// or an ``ImmediateClock``.
///
/// To write a test for this feature we can construct a `FeatureModel` with a ``TestClock``, then
/// advance the clock forward and assert on how the model changes:
///
/// ```swift
/// @Test
/// func timer() async {
///   let clock = TestClock()
///   let model = FeatureModel(clock: clock)
///
///   #expect(model.count == 0)
///   model.startTimerButtonTapped()
///
///   await clock.advance(by: .seconds(1))
///   #expect(model.count == 1)
///
///   await clock.advance(by: .seconds(4))
///   #expect(model.count == 5)
///
///   model.stopTimerButtonTapped()
///   await clock.run()
/// }
/// ```
///
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class TestClock<Duration: DurationProtocol & Hashable>: NonsendingClock, Sendable {
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

  public var minimumResolution: Duration { .zero }
  public var now: Instant { self.state.withLock { $0.now } }

  private let state: LockIsolated<State>

  public init(now: Instant = .init()) {
    self.state = LockIsolated(State(now: now))
  }

  public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
    try await self.sleep(
      until: deadline,
      tolerance: tolerance,
      isolation: #isolation
    )
  }

  public func sleep(
    until deadline: Instant,
    tolerance: Duration? = nil,
    isolation: isolated (any Actor)?
  ) async throws {
    try Task.checkCancellation()
    let id = GUID.next()
    guard let isolation
    else {
      reportIssue(
        """
        TestClock cannot deterministically advance a sleep from a nonisolated concurrent \
        context. Call the clock from actor-isolated code.
        """
      )
      return
    }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let registration = self.state.withLock { state in
          guard !Task.isCancelled else { return Registration.cancelled }
          guard deadline >= state.now else { return Registration.deadlinePassed }
          state.sleeps.append(
            State.Sleep(
              id: id,
              deadline: deadline,
              isolation: isolation,
              continuation: continuation
            )
          )
          return Registration.sleep
        }
        switch registration {
        case .cancelled:
          continuation.resume(throwing: CancellationError())
        case .deadlinePassed:
          continuation.resume()
        case .sleep:
          break
        }
      }
    } onCancel: {
      let sleep: State.Sleep? = self.state.withLock { state in
        guard let index = state.sleeps.firstIndex(where: { $0.id == id })
        else {
          return nil
        }
        return state.sleeps.remove(at: index)
      }
      sleep?.continuation.resume(throwing: CancellationError())
    }
    defer {
      let continuation = self.state.withLock {
        $0.advancementContinuations.removeValue(forKey: id)
      }
      continuation?.resume()
    }
    try Task.checkCancellation()
  }

  /// Advances the test clock's internal time by the duration.
  ///
  /// See the documentation for ``TestClock`` to see how to use this method.
  public func advance(by duration: Duration = .zero) async {
    await self.advance(to: self.now.advanced(by: duration))
  }

  /// Advances the test clock's internal time to the deadline.
  ///
  /// See the documentation for ``TestClock`` to see how to use this method.
  public func advance(to deadline: Instant) async {
    while true {
      let sleep: State.Sleep? = self.state.withLock { state in
        guard deadline >= state.now else { return nil }
        state.sleeps.sort { $0.deadline < $1.deadline }
        guard
          let next = state.sleeps.first,
          deadline >= next.deadline
        else {
          state.now = deadline
          return nil
        }
        state.now = next.deadline
        state.sleeps.removeFirst()
        return next
      }
      guard let sleep else { return }
      await sleep.isolation.run { isolation in
        await withCheckedContinuation { continuation in
          self.state.withLock {
            $0.advancementContinuations[sleep.id] = continuation
          }
          sleep.continuation.resume()
        }
      }
    }
  }

  /// Runs the clock until it has no scheduled sleeps left.
  ///
  /// This method is useful for letting a clock run to its end without having to explicitly account
  /// for each sleep. By default, it suspends until all sleeps finish. It is possible to run a clock
  /// that never finishes, such as one with an unbounded timer. Pass a timeout to report an issue if
  /// the timeout duration is reached.
  ///
  /// - Parameters:
  ///   - duration: The optional amount of time to allow for all work on the clock to finish.
  public func run(
    timeout duration: Swift.Duration? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    func run() async {
      while let deadline = self.state.withLock({
        $0.sleeps.min(by: { $0.deadline < $1.deadline })?.deadline
      }) {
        await self.advance(to: deadline)
      }
    }
    guard let duration
    else {
      await run()
      return
    }

    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          try await Task.sleep(for: duration)
          throw CancellationError()
        }
        group.addTask {
          await run()
        }
        try await group.next()
        group.cancelAll()
      }
    } catch {
      reportIssue(
        """
        Expected all sleeps to finish, but some are still suspending after \(duration).

        There are sleeps suspending. This could mean you are not advancing the test clock far enough
        for your feature to execute its logic, or there could be a bug in your feature's logic.

        You can also increase the timeout of 'run' to be greater than \(duration).
        """,
        fileID: file,
        line: line
      )
    }
  }

  /// Throws an error if there are active sleeps on the clock.
  ///
  /// This can be useful for proving that your feature will not perform any more time-based
  /// asynchrony. For example, the following will throw because the clock has an active suspension
  /// scheduled:
  ///
  /// ```swift
  /// let clock = TestClock()
  /// Task {
  ///   try await clock.sleep(for: .seconds(1))
  /// }
  /// try await clock.checkSleeps()
  /// ```
  ///
  /// However, the following will not throw because advancing the clock has finished the suspension:
  ///
  /// ```swift
  /// let clock = TestClock()
  /// Task {
  ///   try await clock.sleep(for: .seconds(1))
  /// }
  /// await clock.advance(for: .seconds(1))
  /// try await clock.checkSleeps()
  /// ```
  public func checkSleeps() throws {
    guard state.withLock(\.sleeps.isEmpty)
    else { throw SuspensionError() }
  }

  private struct State {
    var now: Instant
    var advancementContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    var sleeps: [Sleep] = []

    struct Sleep {
      let id: Int
      let deadline: Instant
      let isolation: any Actor
      let continuation: CheckedContinuation<Void, any Error>
    }
  }

  private enum Registration {
    case cancelled
    case deadlinePassed
    case sleep
  }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension TestClock where Duration == Swift.Duration {
  public convenience init() {
    self.init(now: .init())
  }
}

/// An error that indicates there are actively suspending sleeps scheduled on the clock.
///
/// This error is thrown automatically by ``TestClock/checkSleeps()`` if there are actively
/// suspending sleeps scheduled on the clock.
public struct SuspensionError: Error {}

extension Actor {
  nonisolated(nonsending)
    package func run(operation: (isolated Self) async -> Void) async
  {
    await operation(self)
  }
}

private enum GUID {
  private static let id = LockIsolated(0)
  static func next() -> Int {
    id.withLock {
      $0 += 1
      return $0
    }
  }
}

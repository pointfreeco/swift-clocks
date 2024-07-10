#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  import ConcurrencyExtras
  import Foundation
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
  /// class FeatureModel: ObservableObject {
  ///   @Published var count = 0
  ///   let clock: any Clock<Duration>
  ///   var timerTask: Task<Void, Error>?
  ///
  ///   init(clock: any Clock<Duration>) {
  ///     self.clock = clock
  ///   }
  ///   func startTimerButtonTapped() {
  ///     self.timerTask = Task {
  ///       while true {
  ///         try await self.clock.sleep(for: .seconds(5))
  ///         self.count += 1
  ///       }
  ///     }
  ///   }
  ///   func stopTimerButtonTapped() {
  ///     self.timerTask?.cancel()
  ///     self.timerTask = nil
  ///   }
  /// }
  /// ```
  ///
  /// Here we have explicitly forced a clock to be provided in order to construct the `FeatureModel`.
  /// This makes it possible to use a real life clock, such as `ContinuousClock`, when running on a
  /// device or simulator, and use a more controllable clock in tests, such as the ``TestClock``.
  ///
  /// To write a test for this feature we can construct a `FeatureModel` with a ``TestClock``, then
  /// advance the clock forward and assert on how the model changes:
  ///
  /// ```swift
  /// func testTimer() async {
  ///   let clock = TestClock()
  ///   let model = FeatureModel(clock: clock)
  ///
  ///   XCTAssertEqual(model.count, 0)
  ///   model.startTimerButtonTapped()
  ///
  ///   await clock.advance(by: .seconds(1))
  ///   XCTAssertEqual(model.count, 1)
  ///
  ///   await clock.advance(by: .seconds(4))
  ///   XCTAssertEqual(model.count, 5)
  ///
  ///   model.stopTimerButtonTapped()
  ///   await clock.run()
  /// }
  /// ```
  ///
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  public final class TestClock<Duration: DurationProtocol & Hashable>: Clock, @unchecked Sendable {
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

    public var minimumResolution: Duration = .zero
    public private(set) var now: Instant

    private let lock = NSRecursiveLock()
    private var suspensions:
      [(
        id: UUID,
        deadline: Instant,
        continuation: AsyncThrowingStream<Never, Error>.Continuation
      )] = []

    public init(now: Instant = .init()) {
      self.now = now
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
      try Task.checkCancellation()
      let id = UUID()
      do {
        let stream: AsyncThrowingStream<Never, Error>? = self.lock.sync {
          guard deadline >= self.now
          else {
            return nil
          }
          return AsyncThrowingStream<Never, Error> { continuation in
            self.suspensions.append((id: id, deadline: deadline, continuation: continuation))
          }
        }
        guard let stream = stream
        else { return }
        for try await _ in stream {}
        try Task.checkCancellation()
      } catch is CancellationError {
        self.lock.sync { self.suspensions.removeAll(where: { $0.id == id }) }
        throw CancellationError()
      } catch {
        throw error
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
    /// try await clock.checkSuspension()
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
    /// try await clock.checkSuspension()
    /// ```
    public func checkSuspension() async throws {
      await Task.megaYield()
      guard self.lock.sync(operation: { self.suspensions.isEmpty })
      else { throw SuspensionError() }
    }

    /// Advances the test clock's internal time by the duration.
    ///
    /// See the documentation for ``TestClock`` to see how to use this method.
    public func advance(by duration: Duration = .zero) async {
      await self.advance(to: self.lock.sync(operation: { self.now.advanced(by: duration) }))
    }

    /// Advances the test clock's internal time to the deadline.
    ///
    /// See the documentation for ``TestClock`` to see how to use this method.
    public func advance(to deadline: Instant) async {
      while self.lock.sync(operation: { self.now <= deadline }) {
        await Task.megaYield()
        let `return` = {
          self.lock.lock()
          self.suspensions.sort { $0.deadline < $1.deadline }

          guard
            let next = self.suspensions.first,
            deadline >= next.deadline
          else {
            self.now = deadline
            self.lock.unlock()
            return true
          }

          self.now = next.deadline
          self.suspensions.removeFirst()
          self.lock.unlock()
          next.continuation.finish()
          return false
        }()

        if `return` {
          await Task.megaYield()
          return
        }
      }
      await Task.megaYield()
    }

    /// Runs the clock until it has no scheduled sleeps left.
    ///
    /// This method is useful for letting a clock run to its end without having to explicitly account
    /// for each sleep. For example, suppose you have a feature that runs a timer for 10 ticks, and
    /// each tick it increments a counter. If you don't want to worry about advancing the timer for
    /// each tick, you can instead just `run` the clock out:
    ///
    /// ```swift
    /// func testTimer() async {
    ///   let clock = TestClock()
    ///   let model = FeatureModel(clock: clock)
    ///
    ///   XCTAssertEqual(model.count, 0)
    ///   model.startTimerButtonTapped()
    ///
    ///   await clock.run()
    ///   XCTAssertEqual(model.count, 10)
    /// }
    /// ```
    ///
    /// It is possible to run a clock that never finishes, hence causing a suspension that never
    /// finishes. This can happen if you create an unbounded timer. In order to prevent holding up
    /// your test suite forever, the ``run(timeout:file:line:)`` method will terminate and cause a
    /// test failure if a timeout duration is reached.
    ///
    /// - Parameters:
    ///   - duration: The amount of time to allow for all work on the clock to finish.
    public func run(
      timeout duration: Swift.Duration = .milliseconds(500),
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) async {
      do {
        try await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask {
            try await Task.sleep(until: .now.advanced(by: duration), clock: .continuous)
            for suspension in self.suspensions {
              suspension.continuation.finish(throwing: CancellationError())
            }
            throw CancellationError()
          }
          group.addTask {
            await Task.megaYield()
            while let deadline = self.lock.sync(operation: { self.suspensions.first?.deadline }) {
              try Task.checkCancellation()
              await self.advance(by: self.lock.sync(operation: { self.now.duration(to: deadline) }))
            }
          }
          try await group.next()
          group.cancelAll()
        }
      } catch {
        reportIssue(
          """
          Expected all sleeps to finish, but some are still suspending after \(duration).

          There are sleeps suspending. This could mean you are not advancing the test clock far \
          enough for your feature to execute its logic, or there could be a bug in your feature's \
          logic.

          You can also increase the timeout of 'run' to be greater than \(duration).
          """,
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
      }
    }
  }

  /// An error that indicates there are actively suspending sleeps scheduled on the clock.
  ///
  /// This error is thrown automatically by ``TestClock/checkSuspension()`` if there are actively
  /// suspending sleeps scheduled on the clock.
  public struct SuspensionError: Error {}

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension TestClock where Duration == Swift.Duration {
    public convenience init() {
      self.init(now: .init())
    }
  }
#endif

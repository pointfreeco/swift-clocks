import IssueReporting
import Testing

@testable import Clocks

@MainActor
@Suite
struct TestClockTests {
  @Test
  @available(anyAppleOS 26.0, *)
  func basics() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    var count = 0
    let task = Task.immediate {
      try await dependency.sleep(for: .seconds(1))
      count += 1
    }

    await clock.run()
    #expect(count == 1)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testExistentialRunsThroughNextSuspension() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    var count = 0

    let task = Task.immediate {
      for _ in 1...100_000 {
        try await dependency.sleep(for: .seconds(1))
        count += 1
      }
    }

    await clock.advance(by: .seconds(100_000))

    #expect(count == 100_000)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testSleepUntil() async throws {
    let clock = TestClock()
    var count = 0

    let task = Task.immediate {
      for _ in 1...10_000 {
        try await clock.sleep(until: clock.now.advanced(by: .seconds(1)))
        count += 1
      }
    }

    await clock.advance(by: .seconds(10_000))

    #expect(count == 10_000)
    try await task.value
  }

  @Test(arguments: Array(1...100))
  @available(anyAppleOS 26.0, *)
  func testRun(_: Int) async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    var count = 0

    let task = Task.immediate {
      for _ in 1...1_000 {
        try await dependency.sleep(for: .seconds(1))
        count += 1
      }
    }

    await clock.run()

    #expect(count == 1_000)
    try await task.value
  }

  @Test(arguments: Array(1...1000))
  @available(anyAppleOS 26.0, *)
  func testTimer(_: Int) async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    let timer = dependency.timer(interval: .seconds(1)).prefix(100)
    var count = 0

    let task = Task.immediate {
      for await _ in timer {
        count += 1
      }
    }

    await clock.run()  //advance(by: .seconds(10_000))

    #expect(count == 100)
    await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testCancellationRemovesSleep() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock

    let task = Task.immediate {
      try await dependency.sleep(for: .seconds(1))
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }

    await clock.advance(by: .seconds(1))
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testCancellationBeforeSleepRegistration() async throws {
    enum Outcome: Equatable, Sendable {
      case finished
      case timedOut
    }

    let clock = TestClock()
    let task = Task.immediate {
      withUnsafeCurrentTask { task in
        task?.cancel()
      }
      try await clock.sleep(for: .seconds(1))
    }

    let outcome = await withTaskGroup(of: Outcome.self) { group in
      group.addTask {
        _ = await task.result
        return .finished
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(1))
        return .timedOut
      }
      let outcome = await group.next()!

      if outcome == .timedOut {
        // If the sleep was incorrectly registered after cancellation, resume it so that the task
        // group can finish and the test does not leak a suspended task.
        await clock.advance(by: .seconds(1))
      }
      group.cancelAll()
      return outcome
    }

    #expect(outcome == .finished)
    await clock.advance(by: .seconds(1))
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test
  @available(anyAppleOS 26.0, *)
  @concurrent
  func testCancellationRacingWithSleepRegistration() async throws {
    let clock = TestClock()
    let completed = LockIsolated(0)
    let attemptCount = 1_000
    var sleepTasks: [Task<Void, Never>] = []

    for _ in 0..<attemptCount {
      let started = LockIsolated(false)
      let sleepTask = LockIsolated<Task<Void, Never>?>(nil)
      let cancellationTask = Task.detached {
        while !started.withLock(\.self) {
          await Task.yield()
        }
        sleepTask.withLock { $0?.cancel() }
      }
      let task = Task { @MainActor in
        started.withLock { $0 = true }
        do {
          try await clock.sleep(for: .seconds(1))
        } catch {
        }
        completed.withLock { $0 += 1 }
      }
      sleepTask.withLock { $0 = task }
      sleepTasks.append(task)
      await cancellationTask.value
    }
    let timeout = ContinuousClock.now.advanced(by: .seconds(1))
    while completed.withLock(\.self) != attemptCount && ContinuousClock.now < timeout {
      await Task.yield()
    }

    let completedBeforeAdvance = completed.withLock(\.self)
    await clock.advance(by: .seconds(1))
    for task in sleepTasks {
      await task.value
    }

    #expect(completedBeforeAdvance == attemptCount)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testAdvanceDoesNotMoveBackward() async throws {
    let clock = TestClock()

    await clock.advance(by: .seconds(10))
    await clock.advance(to: .init(offset: .seconds(5)))

    #expect(clock.now == .init(offset: .seconds(10)))

    await clock.advance(by: .seconds(-5))

    #expect(clock.now == .init(offset: .seconds(10)))
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testNonMainActorRunsThroughNextSuspension() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    let worker = Worker()

    let task = Task.immediate {
      try await worker.run(clock: dependency)
    }
    try await Task.sleep(for: .seconds(0.1))

    await clock.advance(by: .seconds(10_000))

    let count = await worker.count
    #expect(count == 10_000)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testConcreteClockPreservesIsolation() async throws {
    let clock = TestClock()
    let worker = Worker()

    let task = Task.immediate {
      try await worker.run(clock: clock, count: 1_000)
    }
    try await Task.sleep(for: .seconds(0.1))

    await clock.advance(by: .seconds(1_000))

    try await task.value
    let count = await worker.count
    #expect(count == 1_000)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testNonsendingAnyClockPreservesIsolation() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    let erasedClock = AnyClock(dependency)
    let worker = Worker()

    let task = Task.immediate {
      try await worker.run(clock: erasedClock, count: 1_000)
    }
    try await Task.sleep(for: .seconds(0.1))

    await clock.advance(by: .seconds(1_000))

    try await task.value
    let count = await worker.count
    #expect(count == 1_000)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testTimerPreservesIsolation() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    let worker = Worker()

    let task = Task.immediate {
      await worker.runTimer(clock: dependency, count: 1_000)
    }
    try await Task.sleep(for: .seconds(0.1))

    await clock.advance(by: .seconds(1_000))

    await task.value
    let count = await worker.count
    #expect(count == 1_000)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testManualTimerIterationPreservesIsolation() async throws {
    let clock = TestClock()
    let dependency: any NonsendingClock<Swift.Duration> = clock
    let worker = Worker()

    let task = Task.immediate {
      await worker.runManualTimer(clock: dependency, count: 1_000)
    }
    try await Task.sleep(for: .seconds(0.1))

    await clock.advance(by: .seconds(1_000))

    await task.value
    let count = await worker.count
    #expect(count == 1_000)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func testReportsIssueForNonisolatedCaller() async throws {
    let clock = TestClock()

    try await expectReportsIssue {
      let task = Task.immediate {
        try await Self.sleepFromConcurrentContext(clock: clock)
      }
      try await Task.sleep(for: .seconds(0.1))
      await clock.advance(by: .seconds(1))
      try await task.value
    } matching: {
      $0.description.contains("nonisolated concurrent context")
    }
  }

  @available(anyAppleOS 26.0, *)
  @concurrent
  nonisolated private static func sleepFromConcurrentContext(
    clock: TestClock<Swift.Duration>
  ) async throws {
    try await clock.sleep(for: .seconds(1))
  }

  private actor Worker {
    var count = 0

    func run<C: NonsendingClock>(clock: C, count: Int = 10_000) async throws
    where C.Duration == Swift.Duration {
      for _ in 1...count {
        try await clock.sleep(for: .seconds(1))
        self.count += 1
      }
    }

    @available(anyAppleOS 26.0, *)
    func runTimer(clock: any NonsendingClock<Swift.Duration>, count: Int) async {
      for await _ in clock.timer(interval: .seconds(1)).prefix(count) {
        self.count += 1
      }
    }

    func runManualTimer(clock: any NonsendingClock<Swift.Duration>, count: Int) async {
      var iterator = clock.timer(interval: .seconds(1)).makeAsyncIterator()
      for _ in 1...count {
        guard await iterator.next() != nil else { return }
        self.count += 1
      }
    }
  }
}

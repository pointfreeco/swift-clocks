import IssueReporting
import Testing

@testable import Clocks

@MainActor
@Suite struct TestClockTests: ~Copyable {
  let testClock = TestClock()
  let sourceLocation: SourceLocation
  var clock: any NonsendingClock<Duration> { testClock }

  init(sourceLocation: SourceLocation = #_sourceLocation) {
    self.sourceLocation = sourceLocation
  }
  deinit {
    do {
      try testClock.checkSleeps()
    } catch {
      Issue.record(error, sourceLocation: sourceLocation)
    }
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func basics() async throws {
    var count = 0

    var taskFinished = false
    let task = Task.immediate { [clock] in
      try await clock.sleep(for: .seconds(1))
      count += 1
      taskFinished = true
    }

    await testClock.run()
    #expect(count == 1)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `sleep for 0 seconds and advance()`() async throws {
    var count = 0

    var taskFinished = false
    let task = Task.immediate { [clock] in
      try await clock.sleep(for: .seconds(0))
      count += 1
      taskFinished = true
    }

    await testClock.advance()
    #expect(count == 1)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `many sleeps`() async throws {
    var count = 0

    var taskFinished = false
    let task = Task.immediate { [clock] in
      for _ in 1...100_000 {
        try await clock.sleep(for: .seconds(1))
        count += 1
      }
      taskFinished = true
    }

    await testClock.advance(by: .seconds(100_000))
    #expect(count == 100_000)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `sleep until`() async throws {
    var count = 0

    var taskFinished = false
    let task = Task.immediate { [testClock] in
      for _ in 1...100_000 {
        try await testClock.sleep(until: testClock.now.advanced(by: .seconds(1)))
        count += 1
      }
      taskFinished = true
    }

    await testClock.advance(by: .seconds(100_000))
    #expect(count == 100_000)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test(arguments: 1...1000)
  @available(anyAppleOS 26.0, *)
  func run(_: Int) async throws {
    var count = 0

    var taskFinished = false
    let task = Task.immediate { [clock] in
      for _ in 1...1_000 {
        try await clock.sleep(for: .seconds(1))
        count += 1
      }
      taskFinished = true
    }

    await testClock.run()
    #expect(count == 1_000)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test(arguments: 1...1000)
  @available(anyAppleOS 26.0, *)
  func timer(_: Int) async throws {
    let timer = clock.timer(interval: .seconds(1)).prefix(100)
    var count = 0

    var taskFinished = false
    let task = Task.immediate {
      for await _ in timer { count += 1 }
      taskFinished = true
    }

    await testClock.advance(by: .seconds(100))
    #expect(count == 100)
    #expect(taskFinished)
    await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `cancellation removes sleep`() async throws {

    var count = 0
    let task = Task.immediate { [clock] in
      try await clock.sleep(for: .seconds(1))
      count += 1
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    #expect(count == 0)
    await testClock.advance(by: .seconds(1))
    #expect(count == 0)
  }

  @Test(.timeLimit(.minutes(1)))
  @available(anyAppleOS 26.0, *)
  func `cancellation before sleep does not add sleep`() async throws {
    var count = 0

    let task = Task.immediate { [clock] in
      withUnsafeCurrentTask { task in
        task?.cancel()
      }
      try await clock.sleep(for: .seconds(1))
      count += 1
    }

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    #expect(count == 0)
    await testClock.advance(by: .seconds(1))
    #expect(count == 0)
  }

  @Test(
    .timeLimit(.minutes(1)),
    arguments: 1...1000
  )
  @available(anyAppleOS 26.0, *)
  func `racing sleep and cancellation stress test`(_: Int) async throws {
    let completed = LockIsolated(0)
    let attemptCount = 1_000
    var sleepTasks: [Task<Void, Never>] = []

    for _ in 1...attemptCount {
      let started = LockIsolated(false)
      let sleepTask = LockIsolated<Task<Void, Never>?>(nil)
      let cancellationTask = Task { @concurrent in
        while !started.withLock(\.self) || sleepTask.withLock({ $0 == nil }) {
          await Task.yield()
        }
        sleepTask.withLock { $0?.cancel() }
      }
      let task = Task { [clock] in
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
    for task in sleepTasks {
      await task.value
    }

    #expect(completed.withLock(\.self) == attemptCount)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `advance cannot move time backwards`() async throws {

    await testClock.advance(by: .seconds(10))
    let now = TestClock<Duration>.Instant(offset: .seconds(10))
    #expect(testClock.now == now)

    await testClock.advance(to: .init(offset: .seconds(5)))
    #expect(testClock.now == now)

    await testClock.advance(by: .seconds(-5))
    #expect(testClock.now == now)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `sleep captures isolation from custom actors`() async throws {
    let worker = CustomIsolation()

    var taskFinished = false
    let task = Task.immediate { [clock] in
      try await worker.sleeps(clock: clock, count: 10_000)
      taskFinished = true
    }
    await worker.run { _ in }

    await testClock.advance(by: .seconds(10_000))
    let count = await worker.count
    #expect(count == 10_000)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `AnyClock preserves isolation`() async throws {
    let erasedClock = AnyClock(clock)
    let worker = CustomIsolation()

    var taskFinished = false
    let task = Task.immediate {
      try await worker.sleeps(clock: erasedClock, count: 1_000)
      taskFinished = true
    }
    await worker.run { _ in }

    await testClock.advance(by: .seconds(1_000))
    let count = await worker.count
    #expect(count == 1_000)
    #expect(taskFinished == true)
    try await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `timers preserve custom isolation`() async throws {
    let worker = CustomIsolation()

    var taskFinished = false
    let task = Task.immediate { [clock] in
      await worker.timer(clock: clock, count: 1_000)
      taskFinished = true
    }
    await worker.run { _ in }

    await testClock.advance(by: .seconds(1_000))
    let count = await worker.count
    #expect(count == 1_000)
    #expect(taskFinished == true)
    await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `timer iterator preserves custom isolation`() async throws {
    let worker = CustomIsolation()

    var taskFinished = false
    let task = Task.immediate { [clock] in
      await worker.timerIterator(clock: clock, count: 1_000)
      taskFinished = true
    }
    await worker.run { _ in }

    await testClock.advance(by: .seconds(1_000))
    let count = await worker.count
    #expect(count == 1_000)
    #expect(taskFinished == true)
    await task.value
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `reports issue when sleeping from nonisolated context`() async throws {
    expectReportsIssue {
      _ = Task.immediate { @concurrent [clock] in
        try await clock.sleep(for: .seconds(1))
      }
    } matching: {
      $0.description.contains("nonisolated concurrent context")
    }
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `reentrant units of work`() async throws {
    let task = Task.immediate { [clock] in
      var count = 0
      try await clock.sleep(for: .seconds(1))
      count += 1
      try await clock.sleep(for: .seconds(1))
      count += 1
      try await clock.sleep(for: .seconds(1))
      count += 1
      try await clock.sleep(for: .seconds(1))
      count += 1
      try await clock.sleep(for: .seconds(1))
      count += 1
      return count
    }
    await testClock.advance(by: .seconds(5))
    let count = try await task.value
    #expect(count == 5)
  }

  @Test
  @available(anyAppleOS 26.0, *)
  func `check sleeps`() async throws {
    _ = Task.immediate { [clock] in try await clock.sleep(for: .seconds(0)) }
    #expect(throws: SuspensionError.self) {
      try testClock.checkSleeps()
    }
    await testClock.run()
  }


  @Test
  @available(anyAppleOS 26.0, *)
  func `TODO`() async throws {
    var events: [Int] = []
    _ = Task.immediate { [clock] in
      try await clock.sleep(for: .seconds(2))
      events.append(0)
    }
    _ = Task.immediate { [clock] in
      try await clock.sleep(for: .seconds(1))
      events.append(1)
    }
    await testClock.run()
    #expect(events == [1, 0])
  }
}

// A custom isolation to show that 'TestClock' and timers capture their surrounding isolation.
private actor CustomIsolation {
  var count = 0

  func sleeps<C: NonsendingClock<Duration>>(clock: C, count: Int) async throws {
    for _ in 1...count {
      try await clock.sleep(for: .seconds(1))
      self.count += 1
    }
  }

  @available(iOS 18.4, macCatalyst 18.4, macOS 15.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *)
  func timer(clock: any NonsendingClock<Duration>, count: Int) async {
    for await _ in clock.timer(interval: .seconds(1)).prefix(count) {
      self.count += 1
    }
  }

  func timerIterator(clock: any NonsendingClock<Duration>, count: Int) async {
    var iterator = clock.timer(interval: .seconds(1)).makeAsyncIterator()
    for _ in 1...count {
      guard await iterator.next() != nil else { return }
      self.count += 1
    }
  }
}

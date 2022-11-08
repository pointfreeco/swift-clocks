import AsyncAlgorithms
import Clocks
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class TestClockTests: XCTestCase, @unchecked Sendable {
  let clock = TestClock()

  override func tearDown() async throws {
    try await super.tearDown()
    try await self.clock.checkSuspension()
  }

  func testAdvance() async {
    let isFinished = ActorIsolated(false)
    Task {
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      await isFinished.setValue(true)
    }

    var checkIsFinished = await isFinished.value
    XCTAssertEqual(checkIsFinished, false)

    await self.clock.advance(by: .seconds(1))
    checkIsFinished = await isFinished.value
    XCTAssertEqual(checkIsFinished, true)
  }

  func testAdvanceWithReentrantUnitsOfWork() async throws {
    let task = Task {
      var count = 0
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      return count
    }

    await self.clock.advance(by: .seconds(5))
    let ticks = try await task.value
    XCTAssertEqual(ticks, 5)
  }

  func testRun() async {
    let isFinished = ActorIsolated(false)
    Task {
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      await isFinished.setValue(true)
    }

    var checkIsFinished = await isFinished.value
    XCTAssertEqual(checkIsFinished, false)

    await self.clock.run()
    checkIsFinished = await isFinished.value
    XCTAssertEqual(checkIsFinished, true)
  }

  #if DEBUG && canImport(Darwin)
    @MainActor
    func testRunWithTimeout() async throws {
      XCTExpectFailure {
        $0.compactDescription == """
          Expected all sleeps to finish, but some are still suspending after 1.0 seconds.

          There are sleeps suspending. This could mean you are not advancing the test clock far \
          enough for your feature to execute its logic, or there could be a bug in your feature's \
          logic.

          You can also increase the timeout of 'run' to be greater than 1.0 seconds.
          """
      }

      let (stream, continuation) = AsyncStream<Never>.streamWithContinuation()
      let isRunning = ActorIsolated(true)
      Task {
        continuation.finish()
        while await isRunning.value {
          try await self.clock.sleep(for: .seconds(1))
        }
      }
      for await _ in stream {}
      await self.clock.run(timeout: .seconds(1))
      await isRunning.setValue(false)
      await self.clock.run(timeout: .seconds(1))
    }
  #endif

  func testRunMultipleUnitsOfWork() async {
    let timer = AsyncTimerSequence(interval: .seconds(1), clock: self.clock)
      .prefix(10)

    let task = Task {
      var ticks = 0
      for await _ in timer {
        ticks += 1
      }
      return ticks
    }

    await self.clock.run(timeout: .seconds(1))
    let ticks = await task.value
    XCTAssertEqual(ticks, 10)
  }

  func testRunWithReentrantUnitsOfWork() async throws {
    let task = Task {
      var count = 0
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      try await self.clock.sleep(until: self.clock.now.advanced(by: .seconds(1)))
      count += 1
      return count
    }

    await self.clock.run()
    let ticks = try await task.value
    XCTAssertEqual(ticks, 5)
  }

  func testCheckScheduledWork() async throws {
    Task { try await self.clock.sleep(for: .seconds(1)) }

    let didThrow: Bool
    do {
      try await self.clock.checkSuspension()
      XCTFail()
      return
    } catch is SuspensionError {
      didThrow = true
    } catch {
      XCTFail()
      return
    }

    XCTAssertEqual(didThrow, true)
    await self.clock.advance(by: .seconds(1))
    try await self.clock.checkSuspension()
  }

  func testCooperativeCancellation() async {
    actor DidFinish {
      var value = false
      func finish() { self.value = true }
    }
    let didFinish = DidFinish()
    let task = Task {
      try await self.clock.sleep(for: .seconds(1))
      await didFinish.finish()
    }

    task.cancel()
    await self.clock.run()

    let actualDidFinish = await didFinish.value
    XCTAssertEqual(actualDidFinish, false)
  }

  func testCancellationRemovesScheduledItem() async throws {
    let (stream, continuation) = AsyncStream<Never>.streamWithContinuation()

    let task = Task {
      continuation.finish()
      try await self.clock.sleep(for: .seconds(1))
    }

    for await _ in stream {}
    await Task.yield()
    task.cancel()

    try await self.clock.checkSuspension()
  }

  func testNow() async throws {
    let task = Task {
      try await self.clock.sleep(for: .seconds(5))
    }
    await self.clock.advance(by: .seconds(5))
    XCTAssertEqual(self.clock.now.offset, .seconds(5))
    try await task.value
  }

  func testRunSorting() async throws {
    let task = Task {
      try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { group in
        group.addTask {
          try await self.clock.sleep(for: .seconds(2))
          return 2
        }
        group.addTask {
          try await Task.sleep(nanoseconds: 500_000_000)
          try await self.clock.sleep(for: .seconds(1))
          return 1
        }
        return try await group.reduce(into: []) { $0.append($1) }
      }
    }

    try await Task.sleep(nanoseconds: 1_000_000_000)
    await self.clock.run()
    let values = try await task.value

    XCTAssertEqual(values, [1, 2])
  }
}

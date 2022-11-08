import AsyncAlgorithms
import Clocks
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class AsyncAlgorithmsTests: XCTestCase, @unchecked Sendable {
  let clock = TestClock()
  var erasedClock: AnyClock<Duration> {
    AnyClock(self.clock)
  }

  override func tearDown() async throws {
    try await super.tearDown()
    try await self.clock.checkSuspension()
  }

  func testTimer() async {
    let timer = AsyncTimerSequence(interval: .seconds(1), clock: self.erasedClock)
      .prefix(10)

    let ticks = ActorIsolated(0)
    let task = Task {
      for await _ in timer {
        await ticks.withValue { $0 += 1 }
      }
    }

    await self.clock.advance(by: .seconds(1))
    var actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 1)

    await self.clock.advance(by: .seconds(4))
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 5)

    await self.clock.advance(by: .seconds(5))
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 10)

    await self.clock.run()
    await task.value
    XCTAssertEqual(actualTicks, 10)
  }

  func testDebounce() async throws {
    let (stream, continuation) = AsyncStream<Void>.streamWithContinuation()

    let ticks = ActorIsolated(0)
    let task = Task {
      for await _ in stream.debounce(for: .seconds(1), clock: self.erasedClock) {
        await ticks.withValue { $0 += 1 }
      }
    }

    // Nothing is emitted immediately after the base stream emits.
    continuation.yield()
    await self.clock.advance()
    var actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 0)

    // Nothing is emitted after half a second.
    await self.clock.advance(by: .milliseconds(500))
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 0)

    // Ping the base stream again.
    continuation.yield()

    // Nothing is emitted after another half a second.
    await self.clock.advance(by: .milliseconds(500))
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 0)

    // Only after waiting a full second after the base emitted do we get an emission.
    await self.clock.advance(by: .milliseconds(500))
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 1)

    // Pending emission is discarded if base stream finishes.
    continuation.yield()
    continuation.finish()
    await self.clock.run()
    await task.value
    XCTAssertEqual(actualTicks, 1)
  }

  func testThrottle() async throws {
    let (stream, continuation) = AsyncStream<Void>.streamWithContinuation()

    let ticks = ActorIsolated(0)
    let task = Task {
      for await _ in stream.throttle(for: .seconds(1), clock: self.erasedClock) {
        await ticks.withValue { $0 += 1 }
      }
    }

    // First base stream value is emitted immediately.
    continuation.yield()
    await self.clock.advance()
    var actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 1)

    // Ping the base stream after half a second.
    await self.clock.advance(by: .milliseconds(500))
    continuation.yield()

    // Nothing is emitted after another half a second.
    await self.clock.advance()
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 1)

    // Ping the base stream after another half a second.
    await self.clock.advance(by: .milliseconds(500))
    continuation.yield()

    // Value is emitted
    await self.clock.advance()
    actualTicks = await ticks.value
    XCTAssertEqual(actualTicks, 2)

    // Pending emission is discarded if base stream finishes.
    continuation.yield()
    continuation.finish()
    await self.clock.run()
    await task.value
    XCTAssertEqual(actualTicks, 2)
  }

  func testSelect_First() async throws {
    let task = Task {
      await Task.select([
        Task {
          try await self.clock.sleep(for: .seconds(1))
          return 1
        },
        Task {
          try await self.clock.sleep(for: .seconds(2))
          return 2
        },
      ])
    }

    await self.clock.advance(by: .seconds(2))

    let winner = try await task.value.value
    XCTAssertEqual(winner, 1)
  }

  func testSelect_Second() async throws {
    let task = Task {
      await Task.select([
        Task {
          try await self.clock.sleep(for: .seconds(2))
          return 1
        },
        Task {
          try await self.clock.sleep(for: .seconds(1))
          return 2
        },
      ])
    }

    await self.clock.advance(by: .seconds(2))

    let winner = try await task.value.value
    XCTAssertEqual(winner, 2)
  }
}

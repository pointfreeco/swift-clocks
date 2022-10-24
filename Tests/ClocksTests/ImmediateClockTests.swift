import Clocks
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ImmediateClockTests: XCTestCase {
  func testTimer() async throws {
    let clock = ImmediateClock()

    let tasks = Task {
      var ticks = 0
      while ticks < 10 {
        try await clock.sleep(for: .seconds(1))
        ticks += 1
      }
      return ticks
    }

    let ticks = try await tasks.value
    XCTAssertEqual(ticks, 10)
    XCTAssertEqual(clock.now, ImmediateClock.Instant().advanced(by: .seconds(10)))
  }

  func testNow() async throws {
    let clock = ImmediateClock()
    try await clock.sleep(for: .seconds(5))
    XCTAssertEqual(clock.now.offset, .seconds(5))
  }

  func testCooperativeCancellation() async throws {
    let clock = ImmediateClock()
    let task = Task {
      try? await Task.sleep(nanoseconds: 1_000_000_000 / 3)
      try await clock.sleep(for: .seconds(1))
    }
    task.cancel()

    do {
      try await task.value
      XCTFail("Task should have thrown an error")
    } catch {}
  }
}

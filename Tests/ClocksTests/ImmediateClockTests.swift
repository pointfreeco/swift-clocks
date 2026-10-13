import Clocks
import XCTest

@available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
final class ImmediateClockTests: XCTestCase {
  func testTimer() async throws {
    let clock = ImmediateClock()

    let tasks = Task.immediate {
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
    let start = clock.now
    try await clock.sleep(for: .seconds(5))
    XCTAssertEqual(start.advanced(by: .seconds(5)), clock.now)
  }

  func testCooperativeCancellation() async throws {
    let clock = ImmediateClock()
    do {
      try await Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await clock.sleep(for: .seconds(1))
      }
      .value
      XCTFail("Task should have thrown an error")
    } catch {}
  }
}

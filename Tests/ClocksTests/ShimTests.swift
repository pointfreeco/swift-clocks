import Clocks
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ShimTests: XCTestCase {
  func testClockSleepFor() async {
    let testClock = TestClock()
    let clock: some Clock<Duration> = testClock

    let isFinished = ActorIsolated(false)
    Task {
      try await clock.sleep(for: .seconds(1))
      await isFinished.setValue(true)
    }

    var checkIsFinished = await isFinished.value
    XCTAssertEqual(checkIsFinished, false)

    await testClock.advance(by: .seconds(1))
    checkIsFinished = await isFinished.value
    XCTAssertEqual(checkIsFinished, true)
  }
}

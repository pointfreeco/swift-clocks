#if DEBUG && canImport(Darwin)
  import Clocks
  import XCTest

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  final class UnimplementedClockTests: XCTestCase {
    func testUnimplementedClock() async throws {
      XCTExpectFailure {
        [
          "failed - Unimplemented: Clock.sleep",
          "failed - Unimplemented: Clock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock: some Clock<Duration> = .unimplemented
      try await clock.sleep(for: .seconds(1))
    }

    func testUnimplementedClock_WithName() async throws {
      XCTExpectFailure {
        [
          "failed - Unimplemented: ContinuousClock.sleep",
          "failed - Unimplemented: ContinuousClock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock: some Clock<Duration> = UnimplementedClock(name: "ContinuousClock")
      try await clock.sleep(for: .seconds(1))
    }

    func testNow() async throws {
      XCTExpectFailure {
        [
          "failed - Unimplemented: Clock.sleep",
          "failed - Unimplemented: Clock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock = UnimplementedClock()
      try await clock.sleep(for: .seconds(5))
    }

    func testCooperativeCancellation() async throws {
      let clock = UnimplementedClock()
      let task = Task {
        XCTExpectFailure {
          [
            "failed - Unimplemented: Clock.sleep",
            "failed - Unimplemented: Clock.now",
          ]
          .contains($0.compactDescription)
        }

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
#endif

#if DEBUG
  import AsyncAlgorithms
  import Clocks
  import XCTest

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  @MainActor
  final class UnimplementedClockTests: XCTestCase {
    func testUnimplementedClock() async throws {
      XCTExpectFailure {
        [
          "Unimplemented: Clock.sleep",
          "Unimplemented: Clock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock: some Clock<Duration> = .unimplemented
      try await clock.sleep(for: .seconds(1))
    }

    func testUnimplementedClock_WithName() async throws {
      XCTExpectFailure {
        [
          "Unimplemented: ContinuousClock.sleep",
          "Unimplemented: ContinuousClock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock: some Clock<Duration> = UnimplementedClock(name: "ContinuousClock")
      try await clock.sleep(for: .seconds(1))
    }

    func testNow() async throws {
      XCTExpectFailure {
        [
          "Unimplemented: Clock.sleep",
          "Unimplemented: Clock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock = UnimplementedClock()
      try await clock.sleep(for: .seconds(5))
      XCTAssertEqual(clock.now.offset, .seconds(5))
    }

    func testCooperativeCancellation() async throws {
      XCTExpectFailure {
        [
          "Unimplemented: Clock.sleep",
          "Unimplemented: Clock.now",
        ]
        .contains($0.compactDescription)
      }

      let clock = UnimplementedClock()
      let task = Task {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
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

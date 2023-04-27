import Foundation

extension Task where Success == Failure, Failure == Never {
  // NB: We would love if this was not necessary. See this forum post for more information:
  //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
  static func megaYield(count: Int = defaultMegaYieldCount) async {
    for _ in 0..<count {
      await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
    }
  }
}

let defaultMegaYieldCount = max(
  0,
  min(
    ProcessInfo.processInfo.environment["TASK_MEGA_YIELD_COUNT"].flatMap(Int.init) ?? 20,
    10_000
  )
)

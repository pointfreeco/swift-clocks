extension Task where Success == Failure, Failure == Never {
  // NB: We would love if this was not necessary, but due to a lack of async testing tools in Swift
  //     we're not sure if there is an alternative. See this forum post for more information:
  //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
  static func megaYield(count: Int = 10) async {
    for _ in 1...count {
      await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
    }
  }
}

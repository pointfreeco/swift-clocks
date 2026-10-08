import Foundation
import IssueReporting

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class TestClock2<Duration: DurationProtocol & Hashable>: Clock, @unchecked Sendable {
  public struct Instant: InstantProtocol {
    fileprivate let offset: Duration

    public init(offset: Duration = .zero) {
      self.offset = offset
    }

    public func advanced(by duration: Duration) -> Self {
      .init(offset: self.offset + duration)
    }

    public func duration(to other: Self) -> Duration {
      other.offset - self.offset
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.offset < rhs.offset
    }
  }

  public var minimumResolution: Duration { .zero }
  public var now: Instant { self.state.withLock { $0.now } }

  private let state: _LockIsolated<State>

  public init(now: Instant = .init()) {
    self.state = _LockIsolated(State(now: now))
  }

  nonisolated(nonsending)
    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws
  {
    try await self.sleep(
      until: deadline,
      tolerance: tolerance,
      isolation: #isolation
    )
  }

  public func sleep(
    until deadline: Instant,
    tolerance: Duration? = nil,
    isolation: isolated (any Actor)?
  ) async throws {
    try Task.checkCancellation()
    let id = UUID()
    guard let isolation
    else {
      reportIssue(
        """
        TestClock cannot deterministically advance a sleep from a nonisolated concurrent \
        context. Call the clock from actor-isolated code.
        """
      )
      return
    }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let registration = self.state.withLock { state in
          guard !Task.isCancelled else { return Registration.cancel }
          guard deadline >= state.now else { return Registration.resume }
          state.sleeps.append(
            State.Sleep(
              id: id,
              deadline: deadline,
              isolation: isolation,
              continuation: continuation
            )
          )
          return Registration.sleep
        }
        switch registration {
        case .cancel:
          continuation.resume(throwing: CancellationError())
        case .resume:
          continuation.resume()
        case .sleep:
          break
        }
      }
    } onCancel: {
      let sleep: State.Sleep? = self.state.withLock { state in
        guard let index = state.sleeps.firstIndex(where: { $0.id == id })
        else {
          return nil
        }
        return state.sleeps.remove(at: index)
      }
      sleep?.continuation.resume(throwing: CancellationError())
    }
    defer {
      let continuation = self.state.withLock {
        $0.advancementContinuations.removeValue(forKey: id)
      }
      continuation?.resume()
    }
    try Task.checkCancellation()
  }

  public func advance(by duration: Duration = .zero) async {
    await self.advance(to: self.now.advanced(by: duration))
  }

  public func advance(to deadline: Instant) async {
    while true {
      let sleep: State.Sleep? = self.state.withLock { state in
        guard deadline >= state.now else { return nil }
        state.sleeps.sort { $0.deadline < $1.deadline }
        guard
          let next = state.sleeps.first,
          deadline >= next.deadline
        else {
          state.now = deadline
          return nil
        }
        state.now = next.deadline
        state.sleeps.removeFirst()
        return next
      }
      guard let sleep else { return }
      await sleep.isolation.run { isolation in
        await withCheckedContinuation { continuation in
          self.state.withLock {
            $0.advancementContinuations[sleep.id] = continuation
          }
          sleep.continuation.resume()
        }
      }
    }
  }

  public func run() async {
    while true {
      let deadline = self.state.withLock {
        $0.sleeps.min(by: { $0.deadline < $1.deadline })?.deadline
      }
      guard let deadline else { return }
      await self.advance(to: deadline)
    }
  }

  private struct State {
    var now: Instant
    var advancementContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]
    var sleeps: [Sleep] = []

    struct Sleep {
      let id: UUID
      let deadline: Instant
      let isolation: any Actor
      let continuation: CheckedContinuation<Void, any Error>
    }
  }

  private enum Registration {
    case cancel
    case resume
    case sleep
  }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension TestClock2 where Duration == Swift.Duration {
  public convenience init() {
    self.init(now: .init())
  }
}

extension Actor {
  nonisolated(nonsending)
  fileprivate func run(operation: (isolated Self) async -> Void) async {
    await operation(self)
  }
}

@dynamicMemberLookup
final actor ActorIsolated<Value: Sendable> {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }

  subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  func withValue<T: Sendable>(
    _ operation: @Sendable (inout Value) async throws -> T
  ) async rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try await operation(&value)
  }

  func setValue(_ newValue: Value) {
    self.value = newValue
  }
}

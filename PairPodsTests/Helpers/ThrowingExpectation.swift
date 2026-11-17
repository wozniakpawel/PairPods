//
//  ThrowingExpectation.swift
//  PairPodsTests
//

import Foundation

/// Runs a main-actor throwing operation and hands back whatever it threw.
///
/// `#expect(throws:)` takes a closure it may run from a nonisolated context. Passing it a
/// `@MainActor` closure compiles under some Swift 6 toolchains and is rejected by others
/// with "sending main actor-isolated value ... risks causing data races", which is why CI
/// failed on a build that was green locally. Capturing the error on the caller's actor
/// sidesteps the isolation crossing entirely.
@MainActor
func errorThrown(by body: @MainActor () async throws -> Void) async -> Error? {
    do {
        try await body()
        return nil
    } catch {
        return error
    }
}

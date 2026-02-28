//
//  AppErrorTests.swift
//  PairPodsTests
//

import Testing
@testable import PairPods

@Suite("AppError")
struct AppErrorTests {
    @Test("handleError wraps unknown errors in systemError")
    func handleErrorWrapsUnknownError() {
        struct SomeError: Error {}
        let result = handleError(SomeError(), context: "test context")

        if case .systemError = result {
            // Expected
        } else {
            Issue.record("Expected .systemError, got \(result)")
        }
    }

    @Test("handleError passes through existing AppError unchanged")
    func handleErrorPassesThroughAppError() {
        let original = AppError.operationError("test message")
        let result = handleError(original, context: "test context")

        if case let .operationError(message) = result {
            #expect(message == "test message")
        } else {
            Issue.record("Expected .operationError, got \(result)")
        }
    }
}

import Foundation
import XCTest
@testable import Ottu

@MainActor
final class AssistantRequestControllerTests: XCTestCase {
    func testSuccessCompletesOnceAndBusyStartIsIgnored() async {
        let controller = AssistantRequestController<String>(timeout: 1)
        let completed = expectation(description: "request completed")
        var outcomes: [String] = []

        controller.start(operation: { "first" }) { outcome in
            if case let .success(value) = outcome {
                outcomes.append("success:\(value)")
            } else {
                outcomes.append("unexpected")
            }
            completed.fulfill()
        }
        controller.start(operation: { "ignored" }) { _ in
            outcomes.append("duplicate")
        }

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(outcomes, ["success:first"])
        XCTAssertFalse(controller.isWorking)
    }

    func testOperationErrorIsReportedAsFailure() async {
        enum ExpectedError: Error { case requestFailed }

        let controller = AssistantRequestController<String>(timeout: 1)
        let completed = expectation(description: "failure reported")

        controller.start(operation: { throw ExpectedError.requestFailed }) { outcome in
            guard case let .failure(error) = outcome else {
                XCTFail("Expected failure, received \(outcome)")
                completed.fulfill()
                return
            }
            XCTAssertTrue(error is ExpectedError)
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertFalse(controller.isWorking)
    }

    func testFailureClearsLoadingAndAllowsRetry() async {
        enum ExpectedError: Error { case unavailable }

        let controller = AssistantRequestController<String>(timeout: 1)
        let failed = expectation(description: "failure reported")
        let retried = expectation(description: "retry succeeded")
        var outcomes: [String] = []

        controller.start(operation: { throw ExpectedError.unavailable }) { outcome in
            guard case .failure = outcome else {
                XCTFail("Expected failure, received \(outcome)")
                failed.fulfill()
                return
            }
            outcomes.append("failure")
            failed.fulfill()
        }

        await fulfillment(of: [failed], timeout: 1)
        XCTAssertFalse(controller.isWorking)

        controller.start(operation: { "recovered" }) { outcome in
            guard case let .success(value) = outcome else {
                XCTFail("Expected retry success, received \(outcome)")
                retried.fulfill()
                return
            }
            outcomes.append("success:\(value)")
            retried.fulfill()
        }

        await fulfillment(of: [retried], timeout: 1)
        XCTAssertEqual(outcomes, ["failure", "success:recovered"])
        XCTAssertFalse(controller.isWorking)
    }

    func testCancellationErrorsAreReportedAsCancelled() async {
        let controller = AssistantRequestController<String>(timeout: 1)
        let taskCancellationReported = expectation(description: "task cancellation reported")
        let urlCancellationReported = expectation(description: "URL cancellation reported")

        controller.start(operation: { throw CancellationError() }) { outcome in
            guard case .cancelled = outcome else {
                XCTFail("Expected cancelled outcome")
                taskCancellationReported.fulfill()
                return
            }
            taskCancellationReported.fulfill()
        }
        await fulfillment(of: [taskCancellationReported], timeout: 1)

        controller.start(operation: { throw URLError(.cancelled) }) { outcome in
            guard case .cancelled = outcome else {
                XCTFail("Expected cancelled outcome")
                urlCancellationReported.fulfill()
                return
            }
            urlCancellationReported.fulfill()
        }

        await fulfillment(of: [urlCancellationReported], timeout: 1)
        XCTAssertFalse(controller.isWorking)
    }

    func testCancelFinishesImmediatelyAndCanSuppressNotification() async {
        let controller = AssistantRequestController<String>(timeout: 1)
        let operationStarted = expectation(description: "operation started")
        let cancelled = expectation(description: "cancel callback")
        var continuation: CheckedContinuation<String, Error>?

        controller.start(operation: {
            try await withCheckedThrowingContinuation { (saved: CheckedContinuation<String, Error>) in
                continuation = saved
                operationStarted.fulfill()
            }
        }) { outcome in
            guard case .cancelled = outcome else {
                XCTFail("Expected cancelled outcome")
                cancelled.fulfill()
                return
            }
            cancelled.fulfill()
        }

        await fulfillment(of: [operationStarted], timeout: 1)
        controller.cancel()
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertFalse(controller.isWorking)

        let silentStarted = expectation(description: "second operation started")
        var silentContinuation: CheckedContinuation<String, Error>?
        var silentCallbackCount = 0
        controller.start(operation: {
            try await withCheckedThrowingContinuation { (saved: CheckedContinuation<String, Error>) in
                silentContinuation = saved
                silentStarted.fulfill()
            }
        }) { _ in
            silentCallbackCount += 1
        }
        await fulfillment(of: [silentStarted], timeout: 1)
        controller.cancel(notify: false)
        XCTAssertFalse(controller.isWorking)
        XCTAssertEqual(silentCallbackCount, 0)

        continuation?.resume(returning: "late after cancel")
        silentContinuation?.resume(returning: "late after silent cancel")
    }

    func testTimeoutAllowsRetryAndIgnoresLateResultWithoutDuplicateCompletion() async {
        let controller = AssistantRequestController<String>(timeout: 0.03)
        let operationStarted = expectation(description: "noncooperative operation started")
        let timedOut = expectation(description: "timeout reported")
        let retried = expectation(description: "retry completed")
        var suspendedOperation: CheckedContinuation<String, Error>?
        var outcomes: [String] = []

        controller.start(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                suspendedOperation = continuation
                operationStarted.fulfill()
            }
        }) { outcome in
            guard case .timedOut = outcome else {
                XCTFail("Expected timeout outcome")
                outcomes.append("unexpected")
                timedOut.fulfill()
                return
            }
            outcomes.append("timedOut")
            timedOut.fulfill()
        }

        await fulfillment(of: [operationStarted, timedOut], timeout: 2)
        XCTAssertFalse(controller.isWorking)

        controller.start(operation: { "retry" }) { outcome in
            if case let .success(value) = outcome {
                outcomes.append("success:\(value)")
            } else {
                outcomes.append("unexpected retry outcome")
            }
            retried.fulfill()
        }
        await fulfillment(of: [retried], timeout: 1)

        suspendedOperation?.resume(returning: "stale")
        try? await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(outcomes, ["timedOut", "success:retry"])
        XCTAssertFalse(controller.isWorking)
    }
}

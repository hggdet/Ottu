import Combine
import Foundation

enum AssistantRequestOutcome<Response> {
    case success(Response)
    case failure(Error)
    case timedOut
    case cancelled
}

@MainActor
final class AssistantRequestController<Response>: ObservableObject {
    @Published private(set) var isWorking = false

    private let timeoutNanoseconds: UInt64
    private var activeRequestID: UUID?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var onCompletion: (@MainActor (AssistantRequestOutcome<Response>) -> Void)?

    init(timeout: TimeInterval = 18) {
        let boundedTimeout = timeout.isNaN || timeout <= 0 ? 0 : min(timeout, 1_000_000_000)
        timeoutNanoseconds = UInt64(boundedTimeout * 1_000_000_000)
    }

    func start(
        operation: @escaping @MainActor () async throws -> Response,
        onCompletion: @escaping @MainActor (AssistantRequestOutcome<Response>) -> Void
    ) {
        guard !isWorking else { return }

        let requestID = UUID()
        activeRequestID = requestID
        self.onCompletion = onCompletion
        isWorking = true

        operationTask = Task { @MainActor [weak self] in
            do {
                let response = try await operation()
                self?.finish(requestID, with: .success(response))
            } catch {
                if Self.isCancellationError(error) {
                    self?.finish(requestID, with: .cancelled)
                } else {
                    self?.finish(requestID, with: .failure(error))
                }
            }
        }

        let timeoutNanoseconds = self.timeoutNanoseconds
        timeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
            } catch {
                return
            }
            self?.finish(requestID, with: .timedOut)
        }
    }

    func cancel(notify: Bool = true) {
        guard let requestID = activeRequestID else { return }
        finish(requestID, with: notify ? .cancelled : nil)
    }

    private func finish(_ requestID: UUID, with outcome: AssistantRequestOutcome<Response>?) {
        guard activeRequestID == requestID else { return }

        activeRequestID = nil
        isWorking = false

        let completion = onCompletion
        onCompletion = nil

        operationTask?.cancel()
        operationTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil

        if let outcome {
            completion?(outcome)
        }
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

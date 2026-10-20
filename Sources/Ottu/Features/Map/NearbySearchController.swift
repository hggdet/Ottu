import Combine
import Foundation

/// Observable state for map category searches. Empty results and provider failures
/// remain distinct so the map can show an honest empty or retryable unavailable state.
enum NearbySearchState: Equatable {
    case idle
    case loading
    case results([Place])
    case empty
    case unavailable
}

@MainActor
final class NearbySearchController: ObservableObject {
    @Published private(set) var state: NearbySearchState = .idle

    private struct Request {
        let category: AssistantPlaceCategory
        let coordinate: GeoCoordinate
        let language: String
    }

    private let service: any MapAssistantProviding
    private let timeoutNanoseconds: UInt64
    private let waitForTimeout: @Sendable (UInt64) async throws -> Void
    private var lastRequest: Request?
    private var activeRequestID: UUID?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    init(
        service: any MapAssistantProviding,
        timeout: TimeInterval = 18,
        waitForTimeout: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.service = service
        self.waitForTimeout = waitForTimeout
        let boundedTimeout = timeout.isFinite && timeout > 0 ? min(timeout, 1_000_000_000) : 0
        timeoutNanoseconds = UInt64(boundedTimeout * 1_000_000_000)
    }

    func search(for category: AssistantPlaceCategory, near coordinate: GeoCoordinate, language: String) {
        guard activeRequestID == nil else { return }
        let request = Request(category: category, coordinate: coordinate, language: language)
        lastRequest = request
        begin(request)
    }

    /// Retries the last category search after an unavailable/empty outcome.
    func retry() {
        guard activeRequestID == nil, let lastRequest else { return }
        switch state {
        case .unavailable, .empty:
            break
        case .idle, .loading, .results:
            return
        }
        begin(lastRequest)
    }

    /// Cancels an in-flight operation and restores an explicit, non-loading state.
    /// The returned task can be awaited when a caller needs to drain a provider
    /// that does not cooperate with cancellation; cancellation itself is immediate.
    @discardableResult
    func cancel() -> Task<Void, Never>? {
        guard let requestID = activeRequestID else { return nil }
        let cancelledOperation = operationTask
        finish(requestID, state: .idle)
        return cancelledOperation
    }

    private func begin(_ request: Request) {
        let requestID = UUID()
        activeRequestID = requestID
        state = .loading

        operationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let places = try await service.nearbyPlaces(
                    for: request.category,
                    near: request.coordinate,
                    language: request.language
                )
                guard activeRequestID == requestID else { return }
                finish(requestID, state: places.isEmpty ? .empty : .results(places))
            } catch is CancellationError {
                guard activeRequestID == requestID else { return }
                finish(requestID, state: .idle)
            } catch let error as URLError where error.code == .cancelled {
                guard activeRequestID == requestID else { return }
                finish(requestID, state: .idle)
            } catch {
                guard activeRequestID == requestID else { return }
                finish(requestID, state: .unavailable)
            }
        }

        let timeout = timeoutNanoseconds
        let waitForTimeout = self.waitForTimeout
        timeoutTask = Task { @MainActor [weak self] in
            do {
                try await waitForTimeout(timeout)
                try Task.checkCancellation()
            } catch {
                return
            }
            self?.finish(requestID, state: .unavailable)
        }
    }

    private func finish(_ requestID: UUID, state newState: NearbySearchState) {
        guard activeRequestID == requestID else { return }
        activeRequestID = nil
        state = newState
        operationTask?.cancel()
        operationTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}

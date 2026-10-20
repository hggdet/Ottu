import Combine
import Foundation
import XCTest
@testable import Ottu

@MainActor
final class NearbySearchControllerTests: XCTestCase {
    func testSuccessfulResultsAndValidEmptyResultsAreDifferentStates() async {
        let place = Self.place
        let resultsController = NearbySearchController(service: StubMapAssistantService { _, _, _ in [place] })
        resultsController.search(for: .restaurant, near: Self.coordinate, language: "en")
        await waitFor(.results([place]), controller: resultsController)

        let emptyController = NearbySearchController(service: StubMapAssistantService { _, _, _ in [] })
        emptyController.search(for: .restaurant, near: Self.coordinate, language: "en")
        await waitFor(.empty, controller: emptyController)
    }

    func testProviderFailureIsRetryableAndRetryCanSucceed() async {
        let counter = CallCounter()
        let place = Self.place
        let service = StubMapAssistantService { _, _, _ in
            if await counter.next() == 1 { throw StubError.failed }
            return [place]
        }
        let controller = NearbySearchController(service: service)

        controller.search(for: .pharmacy, near: Self.coordinate, language: "ar")
        await waitFor(.unavailable, controller: controller)
        controller.retry()
        await waitFor(.results([place]), controller: controller)
        let callCount = await counter.value()
        XCTAssertEqual(callCount, 2)
    }

    func testEmptyResultsAllowRetry() async {
        let counter = CallCounter()
        let place = Self.place
        let controller = NearbySearchController(service: StubMapAssistantService { _, _, _ in
            if await counter.next() == 1 { return [] }
            return [place]
        })

        controller.search(for: .fuel, near: Self.coordinate, language: "ar")
        await waitFor(.empty, controller: controller)
        controller.retry()
        await waitFor(.results([place]), controller: controller)
        let callCount = await counter.value()
        XCTAssertEqual(callCount, 2)
    }

    func testRetryDoesNothingInInitialIdleAndResultsStates() async {
        let counter = CallCounter()
        let place = Self.place
        let controller = NearbySearchController(service: StubMapAssistantService { _, _, _ in
            _ = await counter.next()
            return [place]
        })

        controller.retry()
        XCTAssertEqual(controller.state, .idle)
        controller.search(for: .cafe, near: Self.coordinate, language: "en")
        await waitFor(.results([place]), controller: controller)
        controller.retry()
        // Retry is rejected in results, so the state must not change to loading.
        XCTAssertEqual(controller.state, .results([place]))
        let callCount = await counter.value()
        XCTAssertEqual(callCount, 1)
    }

    func testTimeoutStopsLoadingAndRetryStartsANewRequest() async {
        let providerStarted = expectation(description: "first provider started")
        let timerReady = expectation(description: "manual timer waiting")
        let clock = ManualTimeoutClock(onFirstWait: { timerReady.fulfill() })
        let counter = CallCounter()
        let place = Self.place
        let service = StubMapAssistantService { _, _, _ in
            if await counter.next() == 1 {
                let pending = AsyncStream<Void> { _ in }
                providerStarted.fulfill()
                for await _ in pending { }
                try Task.checkCancellation()
            }
            return [place]
        }
        let controller = NearbySearchController(service: service, waitForTimeout: { _ in await clock.wait() })

        controller.search(for: .market, near: Self.coordinate, language: "ku")
        await fulfillment(of: [providerStarted, timerReady], timeout: 2)
        XCTAssertEqual(controller.state, .loading)
        await clock.fire()
        await waitFor(.unavailable, controller: controller)
        controller.retry()
        await waitFor(.results([place]), controller: controller)
        let callCount = await counter.value()
        XCTAssertEqual(callCount, 2)
    }

    func testCancelClearsLoadingAndIgnoresLateCompletion() async {
        let started = expectation(description: "non-cooperative provider suspended")
        let provider = SuspendedProvider(onStart: { started.fulfill() })
        let controller = NearbySearchController(service: StubMapAssistantService { _, _, _ in
            await provider.result()
        })

        controller.search(for: .hotel, near: Self.coordinate, language: "en")
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(controller.state, .loading)
        // Loading must not accept a second request through retry().
        controller.retry()
        XCTAssertEqual(controller.state, .loading)
        let operation = controller.cancel()
        XCTAssertNotNil(operation)
        XCTAssertEqual(controller.state, .idle)
        // lastRequest still exists, so this tests idle after cancellation too.
        controller.retry()
        XCTAssertEqual(controller.state, .idle)

        // CheckedContinuation does not react to task cancellation. Resume with a
        // real late success, then await the controller task itself: this proves
        // its stale-result guard has executed, not merely that the service returned.
        await provider.complete(with: [Self.place])
        await operation?.value
        XCTAssertEqual(controller.state, .idle)
        let callCount = await provider.callCount()
        XCTAssertEqual(callCount, 1)
    }

    private func waitFor(
        _ expected: NearbySearchState,
        controller: NearbySearchController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let reachedState = expectation(description: "state becomes \(expected)")
        let observation = controller.$state
            .first(where: { $0 == expected })
            .sink { _ in reachedState.fulfill() }
        await fulfillment(of: [reachedState], timeout: 2)
        withExtendedLifetime(observation) { }
        XCTAssertEqual(controller.state, expected, file: file, line: line)
    }

    private static let coordinate = GeoCoordinate(latitude: 33.3152, longitude: 44.3661)
    private static let place = Place(
        id: "place-1", name: "Test Place", street: nil, city: "Baghdad", country: "Iraq",
        coordinate: coordinate
    )
}

private enum StubError: Error {
    case failed
    case unexpectedCall
}

private actor SuspendedProvider {
    private var continuation: CheckedContinuation<[Place], Never>?
    private var completedResult: [Place]?
    private var calls = 0
    private let onStart: @Sendable () -> Void

    init(onStart: @escaping @Sendable () -> Void) {
        self.onStart = onStart
    }

    func result() async -> [Place] {
        calls += 1
        // Keep even a premature completion, so a failed start expectation cannot
        // leave the controller task suspended forever during test cleanup.
        if let completedResult {
            onStart()
            return completedResult
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            onStart()
        }
    }

    func complete(with places: [Place]) {
        completedResult = places
        let pending = continuation
        continuation = nil
        pending?.resume(returning: places)
    }

    func callCount() -> Int { calls }
}

private actor ManualTimeoutClock {
    private var continuation: AsyncStream<Void>.Continuation?
    private var onFirstWait: (@Sendable () -> Void)?

    init(onFirstWait: @escaping @Sendable () -> Void) {
        self.onFirstWait = onFirstWait
    }

    func wait() async {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.continuation = continuation
        let notify = onFirstWait
        onFirstWait = nil
        notify?()
        for await _ in stream { break }
    }

    func fire() {
        continuation?.yield(())
        continuation?.finish()
        continuation = nil
    }
}

private actor CallCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }

    func value() -> Int { count }
}

private final class StubMapAssistantService: MapAssistantProviding, @unchecked Sendable {
    private let nearby: @Sendable (AssistantPlaceCategory, GeoCoordinate, String) async throws -> [Place]

    init(nearby: @escaping @Sendable (AssistantPlaceCategory, GeoCoordinate, String) async throws -> [Place]) {
        self.nearby = nearby
    }

    func nearbyPlaces(for category: AssistantPlaceCategory, near coordinate: GeoCoordinate, language: String) async throws -> [Place] {
        try await nearby(category, coordinate, language)
    }

    func weather(at coordinate: GeoCoordinate) async throws -> AssistantWeather {
        throw StubError.unexpectedCall
    }

    func nearbyStreet(at coordinate: GeoCoordinate, language: String) async throws -> String? {
        throw StubError.unexpectedCall
    }
}

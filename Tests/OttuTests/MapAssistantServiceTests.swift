import Foundation
import XCTest
@testable import Ottu

final class MapAssistantServiceTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testNearbyPlacesDecodesSuccessfulResponse() async throws {
        StubURLProtocol.handler = { _ in .response(status: 200, body: Self.placeJSON) }
        let service = makeService(endpoints: ["https://overpass.test/primary"])

        let places = try await service.nearbyPlaces(
            for: .pharmacy,
            near: GeoCoordinate(latitude: 33.3152, longitude: 44.3661),
            language: "en"
        )

        XCTAssertEqual(places.map(\.name), ["Test Pharmacy"])
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
        XCTAssertEqual(StubURLProtocol.requests.first?.httpMethod, "POST")
    }

    func testNearbyPlacesFallsBackToNextEndpointAfterFailure() async throws {
        StubURLProtocol.handler = { request in
            if request.url?.host == "first.test" {
                return .response(status: 503, body: Data())
            }
            return .response(status: 200, body: Self.placeJSON)
        }
        let service = makeService(endpoints: [
            "https://first.test/interpreter",
            "https://second.test/interpreter"
        ])

        let places = try await service.nearbyPlaces(
            for: .cafe,
            near: GeoCoordinate(latitude: 33.3152, longitude: 44.3661),
            language: "en"
        )

        XCTAssertEqual(places.first?.name, "Test Pharmacy")
        XCTAssertEqual(StubURLProtocol.requests.compactMap { $0.url?.host }, ["first.test", "second.test"])
    }

    func testCancellationDoesNotFallBackToAnotherEndpoint() async {
        StubURLProtocol.handler = { _ in .response(status: 200, body: Self.placeJSON, delay: 1) }
        let service = makeService(endpoints: [
            "https://first.test/interpreter",
            "https://second.test/interpreter"
        ])
        let task = Task {
            try await service.nearbyPlaces(
                for: .restaurant,
                near: GeoCoordinate(latitude: 33.3152, longitude: 44.3661),
                language: "en"
            )
        }

        try? await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate")
        } catch is CancellationError {
            // Expected: cancellation must not trigger endpoint fallback.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testSequentialRequestsShareOneBoundedTimeoutBudget() async {
        StubURLProtocol.handler = { _ in .response(status: 503, body: Data(), delay: 0.055) }
        let service = makeService(
            endpoints: (1...5).map { "https://endpoint\($0).test/interpreter" },
            totalTimeout: 0.22,
            endpointTimeout: 0.12
        )

        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await service.nearbyPlaces(
                for: .pharmacy,
                near: GeoCoordinate(latitude: 33.3152, longitude: 44.3661),
                language: "en"
            )
            XCTFail("Expected the endpoints to fail")
        } catch {
            // All attempts fail, or the shared deadline expires before the next one.
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let timeouts = StubURLProtocol.requests.map(\.timeoutInterval)

        XCTAssertGreaterThanOrEqual(timeouts.count, 2)
        XCTAssertLessThanOrEqual(timeouts.count, 5)
        XCTAssertLessThanOrEqual(elapsed, 0.6, "The retry loop should stay within its short shared budget")
        XCTAssertTrue(timeouts.allSatisfy { $0 <= 0.12 })
        XCTAssertLessThan(timeouts.last ?? 1, timeouts.first ?? 0, "Later requests must receive only the remaining budget")
    }

    private func makeService(
        endpoints: [String],
        totalTimeout: TimeInterval = 1,
        endpointTimeout: TimeInterval = 0.4
    ) -> OpenStreetMapAssistantService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        let session = URLSession(configuration: configuration)
        return OpenStreetMapAssistantService(
            session: session,
            overpassEndpoints: endpoints,
            totalTimeout: totalTimeout,
            endpointTimeout: endpointTimeout
        )
    }

    private static let placeJSON = Data(
        #"{"elements":[{"id":1,"type":"node","lat":33.3152,"lon":44.3661,"tags":{"name":"Test Pharmacy"}}]}"#.utf8
    )
}

private final class StubURLProtocol: URLProtocol {
    struct StubResponse {
        let status: Int
        let body: Data
        let delay: TimeInterval

        static func response(status: Int, body: Data, delay: TimeInterval = 0) -> StubResponse {
            StubResponse(status: status, body: body, delay: delay)
        }
    }

    private static let lock = NSLock()
    private static var storedHandler: ((URLRequest) -> StubResponse)?
    private static var storedRequests: [URLRequest] = []

    static var handler: ((URLRequest) -> StubResponse)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedHandler = newValue
        }
    }

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        storedHandler = nil
        storedRequests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.storedRequests.append(request)
        let handler = Self.storedHandler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let result = handler(request)
        DispatchQueue.global().asyncAfter(deadline: .now() + result.delay) { [weak self] in
            guard let self, let url = self.request.url else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: result.status,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: result.body)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

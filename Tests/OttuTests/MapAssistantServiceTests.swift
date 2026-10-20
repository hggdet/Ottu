import CoreLocation
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

        let places = try await service.nearbyPlaces(for: .pharmacy, near: Self.baghdad, language: "en")

        XCTAssertEqual(places.map(\.name), ["Test Pharmacy"])
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
        XCTAssertEqual(StubURLProtocol.requests.first?.httpMethod, "POST")
    }

    func testSecondOverpassEndpointSucceedsAfterFirstFails() async throws {
        StubURLProtocol.handler = { request in
            request.url?.host == "capacity.test"
                ? .response(status: 502, body: Data("queue full".utf8))
                : .response(status: 200, body: Self.placeJSON)
        }
        let service = makeService(endpoints: [
            "https://capacity.test/interpreter",
            "https://second.test/interpreter"
        ])

        let places = try await service.nearbyPlaces(for: .restaurant, near: Self.baghdad, language: "ar")

        XCTAssertEqual(places.map(\.name), ["Test Pharmacy"])
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertEqual(StubURLProtocol.requests.last?.url?.host, "second.test")
    }

    func testHTTP502ThenDNSFailureThrowsNearbyPlacesUnavailable() async {
        StubURLProtocol.handler = { request in
            request.url?.host == "capacity.test"
                ? .response(status: 502, body: Data("queue full".utf8))
                : .failure(.cannotFindHost)
        }
        let service = makeService(endpoints: [
            "https://capacity.test/interpreter",
            "https://dns.test/interpreter"
        ])

        do {
            _ = try await service.nearbyPlaces(for: .restaurant, near: Self.baghdad, language: "en")
            XCTFail("Expected all Overpass endpoints to fail")
        } catch AssistantServiceError.nearbyPlacesUnavailable {
            // Expected typed unavailable state, not a false empty success.
        } catch {
            XCTFail("Expected nearbyPlacesUnavailable, got \(error)")
        }
        XCTAssertEqual(StubURLProtocol.requests.map { $0.url?.host }, ["capacity.test", "dns.test"])
    }

    func testMalformedJSONFallsThroughToNextEndpointThenThrowsUnavailable() async {
        StubURLProtocol.handler = { request in
            request.url?.host == "malformed.test"
                ? .response(status: 200, body: Data("{not json".utf8))
                : .failure(.cannotConnectToHost)
        }
        let service = makeService(endpoints: [
            "https://malformed.test/interpreter",
            "https://next.test/interpreter"
        ])

        do {
            _ = try await service.nearbyPlaces(for: .restaurant, near: Self.baghdad, language: "en")
            XCTFail("Expected malformed JSON followed by endpoint failure to be unavailable")
        } catch AssistantServiceError.nearbyPlacesUnavailable {
            // Expected.
        } catch {
            XCTFail("Expected nearbyPlacesUnavailable, got \(error)")
        }
        XCTAssertEqual(StubURLProtocol.requests.map { $0.url?.host }, ["malformed.test", "next.test"])
    }

    func testOverpassRemarkIsRejectedAndNextEndpointFailureThrowsUnavailable() async {
        StubURLProtocol.handler = { request in
            if request.url?.host == "remark.test" {
                return .response(
                    status: 200,
                    body: Data(#"{"remark":"runtime error: Query timed out","elements":[{"id":7,"type":"node","lat":33.3152,"lon":44.3661,"tags":{"name":"Must not be accepted"}}]}"#.utf8)
                )
            }
            return .response(status: 502, body: Data())
        }
        let service = makeService(endpoints: [
            "https://remark.test/interpreter",
            "https://second.test/interpreter"
        ])

        do {
            _ = try await service.nearbyPlaces(for: .restaurant, near: Self.baghdad, language: "en")
            XCTFail("A response containing an Overpass remark must be rejected")
        } catch AssistantServiceError.nearbyPlacesUnavailable {
            // Expected after the remaining endpoint fails.
        } catch {
            XCTFail("Expected nearbyPlacesUnavailable, got \(error)")
        }
        XCTAssertEqual(StubURLProtocol.requests.map { $0.url?.host }, ["remark.test", "second.test"])
    }

    func testValidEmptyOverpassResponseIsSuccessfulEmptyResult() async throws {
        StubURLProtocol.handler = { _ in .response(status: 200, body: Data(#"{"elements":[]}"#.utf8)) }
        let service = makeService(endpoints: [
            "https://empty.test/interpreter",
            "https://must-not-run.test/interpreter"
        ])

        let places = try await service.nearbyPlaces(for: .restaurant, near: Self.baghdad, language: "en")

        XCTAssertTrue(places.isEmpty)
        XCTAssertEqual(StubURLProtocol.requests.map { $0.url?.host }, ["empty.test"])
    }

    func testCancellationDoesNotFallBackToAnotherEndpoint() async {
        StubURLProtocol.handler = { _ in .response(status: 200, body: Self.placeJSON, delay: 2) }
        let service = makeService(
            endpoints: ["https://first.test/interpreter", "https://second.test/interpreter"],
            totalTimeout: 3,
            endpointTimeout: 2.5
        )
        let task = Task {
            try await service.nearbyPlaces(for: .restaurant, near: Self.baghdad, language: "en")
        }

        try? await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate")
        } catch is CancellationError {
            // Expected: cancellation must not start the next endpoint.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testSequentialRequestsRespectOneSharedBudget() async {
        StubURLProtocol.handler = { _ in .response(status: 503, body: Data(), delay: 0.055) }
        let service = makeService(
            endpoints: (1...5).map { "https://endpoint\($0).test/interpreter" },
            totalTimeout: 0.22,
            endpointTimeout: 0.12
        )

        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await service.nearbyPlaces(for: .pharmacy, near: Self.baghdad, language: "en")
            XCTFail("Expected all providers to fail")
        } catch AssistantServiceError.nearbyPlacesUnavailable {
            // OSM attempts remain inside one shared deadline.
        } catch {
            XCTFail("Expected nearbyPlacesUnavailable, got \(error)")
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let timeouts = StubURLProtocol.requests.map(\.timeoutInterval)

        XCTAssertGreaterThanOrEqual(timeouts.count, 2)
        XCTAssertLessThanOrEqual(timeouts.count, 5)
        XCTAssertLessThanOrEqual(elapsed, 0.6)
        XCTAssertTrue(timeouts.allSatisfy { $0 <= 0.12 })
        XCTAssertLessThan(timeouts.last ?? 1, timeouts.first ?? 0)
    }

    func testArabicNearestRestaurantIntentSelectsNearbyProvider() {
        guard case .nearby(let category) = AssistantIntentMatcher.match("أقرب مطعم") else {
            return XCTFail("The Arabic question must select nearby POI search, not text geocoding")
        }
        XCTAssertEqual(category, .restaurant)
    }

    func testLiveBaghdadRestaurantSearchWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["OTTU_RUN_LIVE_PLACES_TESTS"] == "1" else {
            throw XCTSkip("Set OTTU_RUN_LIVE_PLACES_TESTS=1 to perform a live Overpass lookup")
        }
        guard case .nearby(let category) = AssistantIntentMatcher.match("أقرب مطعم") else {
            return XCTFail("The actual Arabic question must select nearby search")
        }
        let service = OpenStreetMapAssistantService()
        let places = try await service.nearbyPlaces(for: category, near: Self.baghdad, language: "ar")

        XCTAssertFalse(places.isEmpty, "Live lookup should return at least one actual Baghdad restaurant")
        XCTAssertTrue(places.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(places.allSatisfy {
            CLLocation(latitude: Self.baghdad.latitude, longitude: Self.baghdad.longitude)
                .distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <= 5_000
        })
    }

    private func makeService(
        endpoints: [String],
        totalTimeout: TimeInterval = 3,
        endpointTimeout: TimeInterval = 1
    ) -> OpenStreetMapAssistantService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 3
        let session = URLSession(configuration: configuration)
        return OpenStreetMapAssistantService(
            session: session,
            overpassEndpoints: endpoints,
            totalTimeout: totalTimeout,
            endpointTimeout: endpointTimeout
        )
    }

    private static let baghdad = GeoCoordinate(latitude: 33.3152, longitude: 44.3661)
    private static let placeJSON = Data(
        #"{"elements":[{"id":1,"type":"node","lat":33.3152,"lon":44.3661,"tags":{"name":"Test Pharmacy"}}]}"#.utf8
    )
}

private final class StubURLProtocol: URLProtocol {
    struct StubResponse {
        let status: Int
        let body: Data
        let delay: TimeInterval
        let errorCode: URLError.Code?

        static func response(status: Int, body: Data, delay: TimeInterval = 0) -> StubResponse {
            StubResponse(status: status, body: body, delay: delay, errorCode: nil)
        }

        static func failure(_ code: URLError.Code) -> StubResponse {
            StubResponse(status: 0, body: Data(), delay: 0, errorCode: code)
        }
    }

    private static let lock = NSLock()
    private static var storedHandler: ((URLRequest) -> StubResponse)?
    private static var storedRequests: [URLRequest] = []
    private var pendingWork: DispatchWorkItem?

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
        if let errorCode = result.errorCode {
            client?.urlProtocol(self, didFailWithError: URLError(errorCode))
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, let url = self.request.url else { return }
            let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: "HTTP/1.1", headerFields: nil)!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: result.body)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        pendingWork = work
        DispatchQueue.global().asyncAfter(deadline: .now() + result.delay, execute: work)
    }

    override func stopLoading() {
        pendingWork?.cancel()
        pendingWork = nil
    }
}

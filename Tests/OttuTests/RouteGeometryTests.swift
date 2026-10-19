import Foundation
import XCTest
@testable import Ottu

final class RouteGeometryTests: XCTestCase {
    override func tearDown() {
        RouteURLProtocol.responseData = nil
        RouteURLProtocol.lastRequest = nil
        super.tearDown()
    }

    func testRouteRequestUsesLongitudeLatitudeOrderAndDecodesGeoJSON() async throws {
        RouteURLProtocol.responseData = Data(
            #"{"code":"Ok","routes":[{"distance":1200,"duration":180,"geometry":{"coordinates":[[-122.4194,37.7749],[-122.408,37.78],[-122.4,37.8]]},"legs":[{"steps":[{"distance":1200,"name":"Main St","maneuver":{"type":"depart","location":[-122.4194,37.7749]}}]}]}]}"#.utf8
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RouteURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let service = OSRMRouteService(session: session)
        let origin = GeoCoordinate(latitude: 37.7749, longitude: -122.4194)
        let waypoint = GeoCoordinate(latitude: 37.78, longitude: -122.408)
        let destination = GeoCoordinate(latitude: 37.8, longitude: -122.4)

        let plans = try await service.routes(
            from: origin,
            to: destination,
            mode: .driving,
            alternatives: true,
            waypoints: [waypoint]
        )

        let request = try XCTUnwrap(RouteURLProtocol.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "router.project-osrm.org")
        XCTAssertEqual(
            components.path,
            "/route/v1/driving/-122.4194,37.7749;-122.408,37.78;-122.4,37.8"
        )
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "geometries" })?.value, "geojson")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "alternatives" })?.value, "true")

        let route = try XCTUnwrap(plans.first)
        XCTAssertEqual(route.coordinates, [origin, waypoint, destination])
        XCTAssertEqual(route.steps.first?.coordinate, origin)
    }

    func testRouteWithOutOfRangeGeometryIsRejected() async throws {
        RouteURLProtocol.responseData = Data(
            #"{"code":"Ok","routes":[{"distance":100,"duration":60,"geometry":{"coordinates":[[-122.4,37.8],[200,91]]},"legs":[]}]}"#.utf8
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RouteURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let service = OSRMRouteService(session: session)

        do {
            _ = try await service.routes(
                from: GeoCoordinate(latitude: 37.7, longitude: -122.5),
                to: GeoCoordinate(latitude: 37.8, longitude: -122.4),
                mode: .driving,
                alternatives: false,
                waypoints: []
            )
            XCTFail("Invalid geometry must not produce a route plan")
        } catch RouteError.noRoute {
            // Expected: invalid route geometries are omitted before returning plans.
        }
    }
}

private final class RouteURLProtocol: URLProtocol {
    static var responseData: Data?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        guard let data = Self.responseData, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

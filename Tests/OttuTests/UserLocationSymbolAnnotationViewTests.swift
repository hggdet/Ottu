import MapLibre
import QuartzCore
import UIKit
import XCTest
@testable import Ottu

final class UserLocationSymbolAnnotationViewTests: XCTestCase {
    @MainActor
    func testArrowHasFixedScreenSpaceSizeWithoutPerspectiveScaling() throws {
        let marker = UserLocationSymbolAnnotationView()
        let symbol = try XCTUnwrap(marker.subviews.compactMap { $0 as? UIImageView }.first)

        XCTAssertEqual(marker.bounds.size, CGSize(width: 22, height: 22))
        XCTAssertFalse(marker.scalesWithViewingDistance)
        XCTAssertFalse(marker.rotatesToMatchCamera)
        XCTAssertEqual(marker.centerOffset, .zero)
        XCTAssertEqual(marker.backgroundColor, .clear)
        XCTAssertEqual(marker.layer.cornerRadius, 0)
        XCTAssertEqual(marker.layer.borderWidth, 0)
        XCTAssertEqual(marker.layer.shadowOpacity, 0)
        XCTAssertEqual(symbol.bounds.size, CGSize(width: 22, height: 22))
        XCTAssertEqual(symbol.center, CGPoint(x: marker.bounds.midX, y: marker.bounds.midY))
        XCTAssertEqual(symbol.tintColor, .systemBlue)
        XCTAssertEqual(symbol.contentMode, .scaleAspectFit)
        let expected = UIImage(
            systemName: "location.north.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )
        XCTAssertEqual(symbol.image, expected)
    }

    @MainActor
    func testHeadingUpdatesRotateOnlyTheArrowWithoutScalingOrPulsing() throws {
        let marker = UserLocationSymbolAnnotationView()
        let symbol = try XCTUnwrap(marker.subviews.compactMap { $0 as? UIImageView }.first)

        let headings: [Double?] = [nil, 0, 45, 90, 180, 270, 360]
        for heading in headings {
            marker.setScreenHeading(heading)
            XCTAssertEqual(marker.bounds.size, CGSize(width: 22, height: 22))
            XCTAssertEqual(marker.transform, .identity)
            XCTAssertEqual(symbol.bounds.size, CGSize(width: 22, height: 22))
            XCTAssertEqual(hypot(symbol.transform.a, symbol.transform.b), 1, accuracy: 0.0001)
            XCTAssertEqual(hypot(symbol.transform.c, symbol.transform.d), 1, accuracy: 0.0001)
            XCTAssertTrue(marker.layer.animationKeys()?.isEmpty ?? true)
            XCTAssertTrue(symbol.layer.animationKeys()?.isEmpty ?? true)
        }
        marker.setScreenHeading(nil)
        XCTAssertEqual(symbol.transform, .identity)
    }

    @MainActor
    func testPulseOnlyForKnownStationarySpeedIncludingThreshold() throws {
        let marker = UserLocationSymbolAnnotationView()
        let symbol = try XCTUnwrap(marker.subviews.compactMap { $0 as? UIImageView }.first)
        let speeds: [Double?] = [nil, -1, .nan, .infinity, -.infinity, 0, 0.1, 0.5, 0.5001, 1, 15, 0, nil]

        for speed in speeds {
            marker.setSpeed(speed, reduceMotion: false)
            let shouldPulse = speed.map { $0.isFinite && $0 >= 0 && $0 <= 0.5 } ?? false
            XCTAssertEqual(!(symbol.layer.animationKeys()?.isEmpty ?? true), shouldPulse, "speed: \(String(describing: speed))")
            XCTAssertTrue(marker.layer.animationKeys()?.isEmpty ?? true)
            XCTAssertEqual(marker.bounds.size, CGSize(width: 22, height: 22))
            XCTAssertEqual(symbol.bounds.size, CGSize(width: 22, height: 22))
            XCTAssertEqual(symbol.layer.opacity, 1)
        }
    }

    @MainActor
    func testStationaryPulseUsesOnlyOpacityAndPreservesHeading() throws {
        let marker = UserLocationSymbolAnnotationView()
        let symbol = try XCTUnwrap(marker.subviews.compactMap { $0 as? UIImageView }.first)
        marker.setScreenHeading(90)
        let headingTransform = symbol.transform
        marker.setSpeed(0.5, reduceMotion: false)
        let key = try XCTUnwrap(symbol.layer.animationKeys()?.first)
        let pulse = try XCTUnwrap(symbol.layer.animation(forKey: key) as? CABasicAnimation)

        XCTAssertEqual(pulse.keyPath, "opacity")
        XCTAssertEqual(pulse.fromValue as? Double, 1)
        XCTAssertEqual(pulse.toValue as? Double, 0.72)
        XCTAssertEqual(pulse.duration, 1.2)
        XCTAssertTrue(pulse.autoreverses)
        XCTAssertEqual(pulse.repeatCount, .infinity)
        XCTAssertEqual(symbol.transform, headingTransform)
        marker.setScreenHeading(180)
        marker.setSpeed(0.1, reduceMotion: false)
        XCTAssertEqual(symbol.layer.animationKeys()?.count, 1)
        XCTAssertEqual(symbol.transform.a, -1, accuracy: 0.0001)
        XCTAssertEqual(symbol.transform.b, 0, accuracy: 0.0001)

        marker.setSpeed(0.6, reduceMotion: false)
        XCTAssertTrue(symbol.layer.animationKeys()?.isEmpty ?? true)
        XCTAssertEqual(symbol.layer.opacity, 1)
        XCTAssertEqual(symbol.transform.a, -1, accuracy: 0.0001)
    }

    @MainActor
    func testReduceMotionStopsAndPreventsStationaryPulse() throws {
        let marker = UserLocationSymbolAnnotationView()
        let symbol = try XCTUnwrap(marker.subviews.compactMap { $0 as? UIImageView }.first)

        marker.setSpeed(0, reduceMotion: true)
        XCTAssertTrue(symbol.layer.animationKeys()?.isEmpty ?? true)
        marker.setSpeed(0, reduceMotion: false)
        XCTAssertFalse(symbol.layer.animationKeys()?.isEmpty ?? true)
        marker.setSpeed(0, reduceMotion: true)
        XCTAssertTrue(symbol.layer.animationKeys()?.isEmpty ?? true)
        XCTAssertEqual(symbol.layer.opacity, 1)
        marker.setSpeed(0, reduceMotion: false)
        XCTAssertFalse(symbol.layer.animationKeys()?.isEmpty ?? true)
        marker.setSpeed(nil, reduceMotion: false)
        XCTAssertTrue(symbol.layer.animationKeys()?.isEmpty ?? true)
    }

    @MainActor
    func testReduceMotionNotificationRefreshesPulseWithoutAnotherLocationFix() throws {
        let marker = UserLocationSymbolAnnotationView()
        let symbol = try XCTUnwrap(marker.subviews.compactMap { $0 as? UIImageView }.first)
        marker.setSpeed(0, reduceMotion: !UIAccessibility.isReduceMotionEnabled)

        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)

        XCTAssertEqual(symbol.layer.animationKeys()?.isEmpty ?? true, UIAccessibility.isReduceMotionEnabled)
        XCTAssertEqual(symbol.layer.opacity, 1)
    }
}

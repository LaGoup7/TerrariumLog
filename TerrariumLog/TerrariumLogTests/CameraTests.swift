import XCTest
@testable import TerrariumLog

final class CameraTests: XCTestCase {
    func testUnconfiguredCameraIsNotConfigured() {
        let camera = Camera(name: "Cam Terrarium")
        XCTAssertFalse(camera.isConfigured)
    }

    func testCameraWithConnectionTypeButNoStreamURLIsNotConfigured() {
        let camera = Camera(name: "Cam Terrarium", connectionType: .rtsp, streamURL: nil)
        XCTAssertFalse(camera.isConfigured)
    }

    func testCameraWithConnectionTypeAndStreamURLIsConfigured() {
        let camera = Camera(name: "Cam Terrarium", connectionType: .rtsp, streamURL: "rtsp://192.168.1.50:554/stream1")
        XCTAssertTrue(camera.isConfigured)
    }

    func testRTSPPassthroughProviderReturnsStreamURL() {
        let camera = Camera(name: "Cam Terrarium", connectionType: .rtsp, streamURL: "rtsp://192.168.1.50:554/stream1")
        let url = RTSPPassthroughProvider().playableURL(for: camera)
        XCTAssertEqual(url?.absoluteString, "rtsp://192.168.1.50:554/stream1")
    }

    func testRTSPPassthroughProviderReturnsNilWhenUnconfigured() {
        let camera = Camera(name: "Cam Terrarium")
        XCTAssertNil(RTSPPassthroughProvider().playableURL(for: camera))
    }

    func testRTSPProviderInjectsCredentialsIntoURL() {
        let camera = Camera(
            name: "Cam",
            connectionType: .rtsp,
            streamURL: "rtsp://192.168.1.50:554/stream1",
            username: "admin",
            password: "secret"
        )
        let url = RTSPPassthroughProvider().playableURL(for: camera)
        XCTAssertEqual(url?.absoluteString, "rtsp://admin:secret@192.168.1.50:554/stream1")
    }

    func testRTSPProviderKeepsCredentialsAlreadyInURL() {
        let camera = Camera(
            name: "Cam",
            connectionType: .rtsp,
            streamURL: "rtsp://foo:bar@192.168.1.50:554/stream1",
            username: "admin",
            password: "secret"
        )
        let url = RTSPPassthroughProvider().playableURL(for: camera)
        XCTAssertEqual(url?.absoluteString, "rtsp://foo:bar@192.168.1.50:554/stream1")
    }

    func testRTSPProviderBuildsDefaultURLFromIP() {
        let camera = Camera(
            name: "Cam",
            connectionType: .rtsp,
            ipAddress: "192.168.1.50",
            username: "admin",
            password: "secret"
        )
        let url = RTSPPassthroughProvider().playableURL(for: camera)
        XCTAssertEqual(url?.absoluteString, "rtsp://admin:secret@192.168.1.50:554/stream1")
    }

    func testRTSPProviderRedactsPasswordForDisplay() throws {
        let camera = Camera(
            name: "Cam",
            connectionType: .rtsp,
            streamURL: "rtsp://192.168.1.50:554/stream1",
            username: "admin",
            password: "secret"
        )
        let display = try XCTUnwrap(RTSPPassthroughProvider().redactedURLString(for: camera))
        XCTAssertFalse(display.contains("secret"), "Le mot de passe ne doit pas apparaître en clair.")
        XCTAssertTrue(display.contains("admin"))
        XCTAssertTrue(display.contains("192.168.1.50"))
    }
}

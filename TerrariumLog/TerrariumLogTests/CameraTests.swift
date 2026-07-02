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
}

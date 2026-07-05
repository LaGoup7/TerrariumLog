import XCTest
@testable import TerrariumLog

final class OnvifTests: XCTestCase {
    func testMediaXAddrParsing() {
        let xml = """
        <s:Envelope><s:Body><tds:GetCapabilitiesResponse><tds:Capabilities>
        <tt:Media><tt:XAddr>http://192.168.1.50:2020/onvif/service</tt:XAddr>
        <tt:StreamingCapabilities><tt:RTPMulticast>false</tt:RTPMulticast></tt:StreamingCapabilities>
        </tt:Media></tds:Capabilities></tds:GetCapabilitiesResponse></s:Body></s:Envelope>
        """
        XCTAssertEqual(OnvifXML.mediaXAddr(from: xml), "http://192.168.1.50:2020/onvif/service")
    }

    func testFirstProfileTokenParsing() {
        let xml = """
        <trt:GetProfilesResponse>
        <trt:Profiles token="profile_1" fixed="true"><tt:Name>mainStream</tt:Name></trt:Profiles>
        <trt:Profiles token="profile_2" fixed="true"><tt:Name>minorStream</tt:Name></trt:Profiles>
        </trt:GetProfilesResponse>
        """
        XCTAssertEqual(OnvifXML.firstProfileToken(from: xml), "profile_1")
    }

    func testSnapshotUriParsing() {
        let xml = """
        <trt:GetSnapshotUriResponse><trt:MediaUri>
        <tt:Uri>http://192.168.1.50:2020/onvif-http/snapshot?profile_1</tt:Uri>
        <tt:InvalidAfterConnect>false</tt:InvalidAfterConnect>
        </trt:MediaUri></trt:GetSnapshotUriResponse>
        """
        XCTAssertEqual(OnvifXML.uri(from: xml), "http://192.168.1.50:2020/onvif-http/snapshot?profile_1")
    }

    func testMissingFieldsReturnNil() {
        XCTAssertNil(OnvifXML.mediaXAddr(from: "<xml></xml>"))
        XCTAssertNil(OnvifXML.firstProfileToken(from: "<xml></xml>"))
        XCTAssertNil(OnvifXML.uri(from: "<xml></xml>"))
    }
}

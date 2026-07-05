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
        XCTAssertNil(OnvifXML.utcDateTime(from: "<xml></xml>"))
        XCTAssertNil(OnvifXML.faultReason(from: "<xml></xml>"))
    }

    func testUTCDateTimeParsing() throws {
        let xml = """
        <tds:GetSystemDateAndTimeResponse><tds:SystemDateAndTime>
        <tt:UTCDateTime>
        <tt:Time><tt:Hour>7</tt:Hour><tt:Minute>32</tt:Minute><tt:Second>10</tt:Second></tt:Time>
        <tt:Date><tt:Year>2026</tt:Year><tt:Month>7</tt:Month><tt:Day>5</tt:Day></tt:Date>
        </tt:UTCDateTime>
        </tds:SystemDateAndTime></tds:GetSystemDateAndTimeResponse>
        """
        let date = try XCTUnwrap(OnvifXML.utcDateTime(from: xml))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 5)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 32)
        XCTAssertEqual(components.second, 10)
    }

    func testFaultReasonParsing() {
        let xml = """
        <s:Fault><s:Code><s:Value>s:Sender</s:Value>
        <s:Subcode><ter:Value>ter:NotAuthorized</ter:Value></s:Subcode></s:Code>
        <s:Reason><s:Text xml:lang="en">Sender not authorized</s:Text></s:Reason></s:Fault>
        """
        XCTAssertEqual(OnvifXML.faultReason(from: xml), "Sender not authorized")
    }
}

import XCTest
@testable import RKNChecker

final class DiagnosticEngineTests: XCTestCase {
    
    func testTargetItemHostExtraction() {
        let item1 = TargetItem(name: "gosuslugi", url: "https://www.gosuslugi.ru/", isWhitelist: true)
        XCTAssertEqual(item1.host, "www.gosuslugi.ru")
        
        let item2 = TargetItem(name: "telegram", url: "https://t.me/news", isWhitelist: false)
        XCTAssertEqual(item2.host, "t.me")
        
        let item3 = TargetItem(name: "raw-host", url: "invalid-url", isWhitelist: false)
        XCTAssertEqual(item3.host, "raw-host")
    }
    
    func testVerdictProperties() {
        XCTAssertTrue(Verdict.httpStub.isBlocked)
        XCTAssertTrue(Verdict.tlsBlock.isBlocked)
        XCTAssertTrue(Verdict.tcpReset.isBlocked)
        XCTAssertTrue(Verdict.dnsBlock.isBlocked)
        XCTAssertTrue(Verdict.timeout.isBlocked)
        
        XCTAssertFalse(Verdict.ok.isBlocked)
        XCTAssertFalse(Verdict.down.isBlocked)
        XCTAssertFalse(Verdict.testing.isBlocked)
        XCTAssertFalse(Verdict.unknown.isBlocked)
        
        for verdict in Verdict.allCases {
            XCTAssertFalse(verdict.label.isEmpty)
            XCTAssertFalse(verdict.systemImage.isEmpty)
            XCTAssertFalse(verdict.localizedDescription.isEmpty)
        }
    }
    
    func testStubMarkersDetection() {
        XCTAssertEqual(STUB_MARKERS.count, 10)
        
        let sampleBody1 = "<html><body><h1>внимание! доступ ограничен по решению суда</h1></body></html>"
        let isMatch1 = STUB_MARKERS.contains { sampleBody1.contains($0) }
        XCTAssertTrue(isMatch1)
        
        let sampleBody2 = "<html><body><h1>сайт заблокирован единый реестр</h1></body></html>"
        let isMatch2 = STUB_MARKERS.contains { sampleBody2.contains($0) }
        XCTAssertTrue(isMatch2)
        
        let cleanBody = "<html><body><h1>welcome to my personal blog</h1></body></html>"
        let isClean = !STUB_MARKERS.contains { cleanBody.contains($0) }
        XCTAssertTrue(isClean)
    }
    
    @MainActor
    func testTargetListsIntegrity() {
        let vm = CheckerViewModel()
        XCTAssertEqual(vm.whitelistTargets.count, 21)
        XCTAssertEqual(vm.blacklistTargets.count, 15)
        XCTAssertEqual(vm.allTargets.count, 36)
        
        // Проверка отсутствия дубликатов по имени
        let uniqueNames = Set(vm.allTargets.map { $0.name })
        XCTAssertEqual(uniqueNames.count, 36)
    }
}

import XCTest
@testable import Domain

final class DomainTests: XCTestCase {
    func testTrustScoreBounds() {
        let calculator = TrustScoreCalculator()
        XCTAssertEqual(calculator.score(endorsements: 0, reports: 0).value, 0)
        XCTAssertEqual(calculator.score(endorsements: 20, reports: 0).value, 100)
        XCTAssertEqual(calculator.score(endorsements: 0, reports: 10).value, 0)
    }
}

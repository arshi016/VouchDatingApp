import XCTest
@testable import Domain

final class DomainTests: XCTestCase {
    func testTrustScoreBounds() {
        let calculator = TrustScoreCalculator()
        XCTAssertEqual(calculator.score(endorsements: 0, reports: 0).value, 0)
        XCTAssertEqual(calculator.score(endorsements: 20, reports: 0).value, 100)
        XCTAssertEqual(calculator.score(endorsements: 0, reports: 10).value, 0)
    }

    func testOnboardingStateMachineRequiresConsent() {
        var machine = OnboardingStateMachine()
        XCTAssertEqual(machine.state.step, .intro)
        XCTAssertTrue(machine.handle(.next))
        XCTAssertEqual(machine.state.step, .consent)

        XCTAssertFalse(machine.handle(.next))
        XCTAssertEqual(machine.state.step, .consent)

        XCTAssertTrue(machine.handle(.setConsent(camera: true, biometrics: true)))
        XCTAssertTrue(machine.handle(.next))
        XCTAssertEqual(machine.state.step, .privacy)
    }

    func testOnboardingBackNavigation() {
        var machine = OnboardingStateMachine()
        _ = machine.handle(.next)
        _ = machine.handle(.setConsent(camera: true, biometrics: true))
        _ = machine.handle(.next)
        XCTAssertEqual(machine.state.step, .privacy)
        XCTAssertTrue(machine.handle(.back))
        XCTAssertEqual(machine.state.step, .consent)
    }

    func testLivenessStateMachineHappyPath() {
        var machine = LivenessStateMachine()
        XCTAssertEqual(machine.stage, .idle)
        _ = machine.handle(.faceDetected)
        XCTAssertEqual(machine.stage, .faceDetected)
        _ = machine.handle(.blink)
        XCTAssertEqual(machine.stage, .blinkDetected)
        _ = machine.handle(.headTurnLeft)
        XCTAssertEqual(machine.stage, .completed)
    }

    func testLivenessStateMachineFailure() {
        var machine = LivenessStateMachine()
        _ = machine.handle(.multipleFaces)
        XCTAssertEqual(machine.stage, .failed(.multipleFaces))
    }

    func testVerificationGatePolicy() {
        let policy = DefaultVerificationGatePolicy(maxAge: 10)
        let recent = Date().addingTimeInterval(-5)
        XCTAssertFalse(policy.requiresReverification(for: .checkIn, lastVerifiedAt: recent))
        let old = Date().addingTimeInterval(-20)
        XCTAssertTrue(policy.requiresReverification(for: .checkIn, lastVerifiedAt: old))
    }
}

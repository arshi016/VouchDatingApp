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

    func testDiscoverFilterEngine() {
        let profiles = [
            DiscoverProfile(
                id: "1",
                displayName: "A",
                age: 25,
                distanceBucket: "2-5km",
                badges: [],
                isHumanVerified: true,
                isIRLVerified: false,
                intent: .eventsOnly,
                photoURL: nil,
                isBlurred: false,
                summary: "Security analyst"
            ),
            DiscoverProfile(
                id: "2",
                displayName: "B",
                age: 42,
                distanceBucket: "City area",
                badges: [],
                isHumanVerified: false,
                isIRLVerified: false,
                intent: .relationship,
                photoURL: nil,
                isBlurred: true,
                summary: "Event host"
            )
        ]

        let filters = DiscoverFilters(
            ageRange: AgeRange(min: 21, max: 35),
            intent: .eventsOnly,
            humanVerifiedOnly: true,
            irlVerifiedOnly: false
        )
        let engine = DiscoverFilterEngine()
        let filtered = engine.apply(profiles, filters: filters)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "1")
    }

    func testWaveThrottleResetsDaily() {
        let throttler = WaveThrottler(policy: WaveThrottlePolicy(maxPerDay: 2))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let quota = WaveQuota(count: 2, lastReset: yesterday)
        XCTAssertTrue(throttler.canSendWave(quota: quota))
        let updated = throttler.consume(quota: quota)
        XCTAssertEqual(updated.count, 1)
    }

    func testCheckInStateMachine() {
        var machine = CheckInStateMachine()
        XCTAssertEqual(machine.state, .idle)
        _ = machine.handle(.start)
        XCTAssertEqual(machine.state, .scanning)
        _ = machine.handle(.tokenScanned("token"))
        XCTAssertEqual(machine.state, .validating)
        let now = Date()
        _ = machine.handle(.validationSuccess(now))
        XCTAssertEqual(machine.state, .success(now))
    }
}

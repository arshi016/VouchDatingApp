import Foundation

public enum CheckInFailure: Equatable {
    case invalidToken
    case expiredToken
    case wrongEvent
    case alreadyCheckedIn
    case network
}

public enum CheckInState: Equatable {
    case idle
    case scanning
    case validating
    case success(Date)
    case failure(CheckInFailure)
}

public enum CheckInEvent: Equatable {
    case start
    case tokenScanned(String)
    case validationSuccess(Date)
    case validationFailure(CheckInFailure)
    case reset
}

public struct CheckInStateMachine {
    public private(set) var state: CheckInState

    public init(state: CheckInState = .idle) {
        self.state = state
    }

    @discardableResult
    public mutating func handle(_ event: CheckInEvent) -> CheckInState {
        switch event {
        case .start:
            state = .scanning
        case .tokenScanned:
            state = .validating
        case .validationSuccess(let date):
            state = .success(date)
        case .validationFailure(let failure):
            state = .failure(failure)
        case .reset:
            state = .idle
        }
        return state
    }
}

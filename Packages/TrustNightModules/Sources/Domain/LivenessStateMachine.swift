import Foundation

public enum LivenessSignal: Equatable {
    case faceDetected
    case faceLost
    case blink
    case headTurnLeft
    case headTurnRight
    case multipleFaces
    case tooDark
    case timeout
}

public enum LivenessFailure: Equatable {
    case noFace
    case multipleFaces
    case tooDark
    case timeout
}

public enum LivenessStage: Equatable {
    case idle
    case faceDetected
    case blinkDetected
    case headTurnDetected
    case completed
    case failed(LivenessFailure)
}

public struct LivenessStateMachine {
    public private(set) var stage: LivenessStage

    public init(stage: LivenessStage = .idle) {
        self.stage = stage
    }

    @discardableResult
    public mutating func handle(_ signal: LivenessSignal) -> LivenessStage {
        switch signal {
        case .multipleFaces:
            stage = .failed(.multipleFaces)
        case .tooDark:
            stage = .failed(.tooDark)
        case .timeout:
            stage = .failed(.timeout)
        case .faceLost:
            if case .idle = stage {
                stage = .failed(.noFace)
            } else {
                stage = .idle
            }
        case .faceDetected:
            if stage == .idle {
                stage = .faceDetected
            }
        case .blink:
            if stage == .faceDetected {
                stage = .blinkDetected
            }
        case .headTurnLeft, .headTurnRight:
            if stage == .blinkDetected {
                stage = .headTurnDetected
                stage = .completed
            }
        }
        return stage
    }
}

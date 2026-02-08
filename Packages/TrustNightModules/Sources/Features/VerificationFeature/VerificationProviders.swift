import Foundation
import Vision
import CoreImage
import CoreVideo
import Domain

public protocol VerificationProvider {
    func analyze(pixelBuffer: CVPixelBuffer) async -> [LivenessSignal]
    func generateTemplate(from pixelBuffer: CVPixelBuffer) async throws -> Data
}

public final class MockVerificationProvider: VerificationProvider {
    private var frameCount = 0

    public init() {}

    public func analyze(pixelBuffer: CVPixelBuffer) async -> [LivenessSignal] {
        frameCount += 1
        switch frameCount {
        case 1...8:
            return [.faceDetected]
        case 9...14:
            return [.blink]
        case 15...20:
            return [.headTurnLeft]
        default:
            return []
        }
    }

    public func generateTemplate(from pixelBuffer: CVPixelBuffer) async throws -> Data {
        Data("mock_feature_print".utf8)
    }
}

public final class VisionVerificationProvider: VerificationProvider {
    private let queue = DispatchQueue(label: "vision.verification.queue")
    private var lastBlinkClosed = false

    public init() {}

    public func analyze(pixelBuffer: CVPixelBuffer) async -> [LivenessSignal] {
        await withCheckedContinuation { continuation in
            queue.async {
                var signals: [LivenessSignal] = []
                if Self.averageLuma(pixelBuffer) < 0.2 {
                    continuation.resume(returning: [.tooDark])
                    return
                }

                let request = VNDetectFaceLandmarksRequest()
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    if observations.count > 1 {
                        continuation.resume(returning: [.multipleFaces])
                        return
                    }
                    guard let face = observations.first else {
                        continuation.resume(returning: [.faceLost])
                        return
                    }
                    signals.append(.faceDetected)

                    if Self.isBlink(faceObservation: face, previousClosed: &self.lastBlinkClosed) {
                        signals.append(.blink)
                    }

                    if let yaw = face.yaw?.doubleValue {
                        if yaw > 0.25 {
                            signals.append(.headTurnRight)
                        } else if yaw < -0.25 {
                            signals.append(.headTurnLeft)
                        }
                    }
                    continuation.resume(returning: signals)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    public func generateTemplate(from pixelBuffer: CVPixelBuffer) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let request = VNGenerateFaceFeaturePrintRequest()
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([request])
                    guard let result = request.results?.first else {
                        continuation.resume(throwing: VerificationProviderError.templateFailed)
                        return
                    }
                    let data = Data(result.data)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func isBlink(faceObservation: VNFaceObservation, previousClosed: inout Bool) -> Bool {
        guard let leftEye = faceObservation.landmarks?.leftEye,
              let rightEye = faceObservation.landmarks?.rightEye else {
            return false
        }
        let leftRatio = eyeAspectRatio(leftEye)
        let rightRatio = eyeAspectRatio(rightEye)
        let averageRatio = (leftRatio + rightRatio) / 2
        let closed = averageRatio < 0.15
        let blinkDetected = previousClosed == false && closed == true
        previousClosed = closed
        return blinkDetected
    }

    private static func eyeAspectRatio(_ eye: VNFaceLandmarkRegion2D) -> Double {
        let points = eye.normalizedPoints
        guard points.count > 4 else { return 1 }
        let xs = points.map { Double($0.x) }
        let ys = points.map { Double($0.y) }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return 1
        }
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0 else { return 1 }
        return height / width
    }

    private static func averageLuma(_ pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return 0.5 }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let sampleStride = max(1, width / 24)
        var total: Double = 0
        var count: Double = 0

        for y in stride(from: 0, to: height, by: sampleStride) {
            let row = buffer + y * bytesPerRow
            for x in stride(from: 0, to: width, by: sampleStride) {
                total += Double(row[x])
                count += 1
            }
        }

        guard count > 0 else { return 0.5 }
        return (total / count) / 255.0
    }
}

public final class VendorVerificationProvider: VerificationProvider {
    public init() {}

    public func analyze(pixelBuffer: CVPixelBuffer) async -> [LivenessSignal] {
        []
    }

    public func generateTemplate(from pixelBuffer: CVPixelBuffer) async throws -> Data {
        throw VerificationProviderError.notConfigured
    }
}

enum VerificationProviderError: Error {
    case notConfigured
    case templateFailed
}

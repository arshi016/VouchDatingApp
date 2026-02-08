import SwiftUI
import DesignSystem
import FoundationKit
import Networking
import Domain

public struct VerificationDependencies {
    public let analytics: AnalyticsTracking
    public let logger: Logger
    public let service: VerificationService
    public let provider: VerificationProvider

    public init(analytics: AnalyticsTracking, logger: Logger, service: VerificationService, provider: VerificationProvider) {
        self.analytics = analytics
        self.logger = logger
        self.service = service
        self.provider = provider
    }
}

public enum VerificationStage: Equatable {
    case intro
    case capturing
    case processing
    case success
    case failure(String)
}

@MainActor
public final class VerificationViewModel: ObservableObject {
    @Published public private(set) var stage: VerificationStage = .intro
    @Published public private(set) var livenessStage: LivenessStage = .idle
    @Published public private(set) var isVerified = false
    @Published public private(set) var instructionKey: LocalizedStringKey = "verification_instruction_center"
    @Published public private(set) var errorMessage: String?

    public let cameraSession = CameraSession()

    private let dependencies: VerificationDependencies
    private var livenessMachine = LivenessStateMachine()
    private var lastPixelBuffer: CVPixelBuffer?
    private var isProcessingFrame = false
    private var timeoutTask: Task<Void, Never>?

    public init(dependencies: VerificationDependencies) {
        self.dependencies = dependencies
        configureCamera()
        Task { await loadStatus() }
    }

    public func startVerification() {
        errorMessage = nil
        livenessMachine = LivenessStateMachine()
        livenessStage = .idle
        stage = .capturing
        cameraSession.start()
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await self?.applySignals([.timeout])
        }
    }

    public func cancelVerification() {
        cameraSession.stop()
        timeoutTask?.cancel()
        stage = .intro
    }

    public func retryVerification() {
        startVerification()
    }

    public func deleteTemplate() {
        Task {
            await dependencies.service.deleteTemplate()
            isVerified = false
            stage = .intro
        }
    }

    private func configureCamera() {
        do {
            try cameraSession.configure()
            cameraSession.onSampleBuffer = { [weak self] sampleBuffer in
                self?.handleSampleBuffer(sampleBuffer)
            }
        } catch {
            stage = .failure(NSLocalizedString("verification_error_camera", comment: ""))
        }
    }

    private func loadStatus() async {
        let status = await dependencies.service.fetchStatus()
        isVerified = status == .verified
    }

    private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard stage == .capturing, !isProcessingFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isProcessingFrame = true
        lastPixelBuffer = pixelBuffer

        Task {
            let signals = await dependencies.provider.analyze(pixelBuffer: pixelBuffer)
            await applySignals(signals)
            await MainActor.run { self.isProcessingFrame = false }
        }
    }

    private func applySignals(_ signals: [LivenessSignal]) async {
        guard stage == .capturing else { return }
        for signal in signals {
            let newStage = livenessMachine.handle(signal)
            await MainActor.run {
                livenessStage = newStage
                instructionKey = LivenessUIHelper.instructionKey(for: newStage)
            }
            if case .completed = newStage {
                await completeVerification()
                return
            }
            if case let .failed(reason) = newStage {
                await failVerification(reason: reason)
                return
            }
        }
    }

    private func completeVerification() async {
        guard let pixelBuffer = lastPixelBuffer else {
            await failVerification(reason: .noFace)
            return
        }
        await MainActor.run {
            stage = .processing
        }
        cameraSession.stop()
        timeoutTask?.cancel()

        do {
            let template = try await dependencies.provider.generateTemplate(from: pixelBuffer)
            try await dependencies.service.saveTemplate(template)
            try await dependencies.service.markVerified()
            dependencies.analytics.track(AnalyticsEvent(name: "human_verified_success"))
            await MainActor.run {
                isVerified = true
                stage = .success
            }
        } catch {
            dependencies.analytics.track(AnalyticsEvent(name: "human_verified_failure"))
            await failVerification(reason: .timeout)
        }
    }

    private func failVerification(reason: LivenessFailure) async {
        cameraSession.stop()
        timeoutTask?.cancel()
        await MainActor.run {
            stage = .failure(LivenessUIHelper.failureMessage(for: reason))
        }
    }
}

public struct VerificationView: View {
    @StateObject private var viewModel: VerificationViewModel
    private let onCompleted: (() -> Void)?

    public init(viewModel: VerificationViewModel, onCompleted: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrustSpacing.lg) {
                Text("verification_title")
                    .font(TrustTypography.title)
                    .accessibilityAddTraits(.isHeader)
                Text("verification_info")
                    .font(TrustTypography.body)
                    .foregroundStyle(TrustColors.textSecondary)

                if viewModel.isVerified {
                    Badge("verification_badge_verified", style: .success)
                }

                switch viewModel.stage {
                case .intro:
                    VerificationIntroView(viewModel: viewModel)
                case .capturing:
                    VerificationCaptureView(viewModel: viewModel)
                case .processing:
                    VerificationProcessingView()
                case .success:
                    VerificationSuccessView(viewModel: viewModel, onDone: { onCompleted?() })
                case .failure(let message):
                    VerificationFailureView(message: message, onRetry: viewModel.retryVerification)
                }
            }
            .padding(TrustSpacing.lg)
        }
    }
}

private struct VerificationIntroView: View {
    @ObservedObject var viewModel: VerificationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.md) {
            Text("verification_intro_title")
                .font(TrustTypography.headline)
            Text("verification_intro_body")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
            PrimaryButton("verification_start", action: viewModel.startVerification)
        }
    }
}

private struct VerificationCaptureView: View {
    @ObservedObject var viewModel: VerificationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.md) {
            CameraPreviewView(session: viewModel.cameraSession.session)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(TrustColors.accent.opacity(0.3), lineWidth: 1)
                )
                .accessibilityLabel(Text("verification_camera_preview"))

            Text(viewModel.instructionKey)
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textPrimary)
            LivenessProgressView(stage: viewModel.livenessStage)
            SecondaryButton("verification_cancel", action: viewModel.cancelVerification)
        }
    }
}

private struct VerificationProcessingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.md) {
            LoadingSpinner()
            Text("verification_processing")
                .font(TrustTypography.body)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }
}

private struct VerificationSuccessView: View {
    @ObservedObject var viewModel: VerificationViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.md) {
            Toast(titleKey: "verification_success_title", messageKey: "verification_success_body", style: .success)
            PrimaryButton("verification_done", action: onDone)
            DestructiveButton("verification_delete_template", action: viewModel.deleteTemplate)
        }
    }
}

private struct VerificationFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.md) {
            Toast(titleKey: "verification_failure_title", messageKey: LocalizedStringKey(message), style: .danger)
            PrimaryButton("verification_retry", action: onRetry)
        }
    }
}

private struct LivenessProgressView: View {
    let stage: LivenessStage

    var body: some View {
        VStack(alignment: .leading, spacing: TrustSpacing.xs) {
            ProgressView(value: progress)
                .tint(TrustColors.accent)
            Text(progressLabel)
                .font(TrustTypography.caption)
                .foregroundStyle(TrustColors.textSecondary)
        }
    }

    private var progress: Double {
        switch stage {
        case .idle: return 0.1
        case .faceDetected: return 0.4
        case .blinkDetected: return 0.7
        case .headTurnDetected: return 0.9
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }

    private var progressLabel: LocalizedStringKey {
        switch stage {
        case .idle: return "verification_progress_ready"
        case .faceDetected: return "verification_progress_face"
        case .blinkDetected: return "verification_progress_blink"
        case .headTurnDetected: return "verification_progress_turn"
        case .completed: return "verification_progress_done"
        case .failed: return "verification_progress_failed"
        }
    }
}

private enum LivenessUIHelper {
    static func instructionKey(for stage: LivenessStage) -> LocalizedStringKey {
        switch stage {
        case .idle:
            return "verification_instruction_center"
        case .faceDetected:
            return "verification_instruction_blink"
        case .blinkDetected:
            return "verification_instruction_turn"
        case .headTurnDetected, .completed:
            return "verification_instruction_hold"
        case .failed:
            return "verification_instruction_retry"
        }
    }

    static func failureMessage(for reason: LivenessFailure) -> String {
        switch reason {
        case .noFace:
            return "verification_fail_no_face"
        case .multipleFaces:
            return "verification_fail_multiple_faces"
        case .tooDark:
            return "verification_fail_too_dark"
        case .timeout:
            return "verification_fail_timeout"
        }
    }
}

#if DEBUG
struct VerificationView_Previews: PreviewProvider {
    static var previews: some View {
        VerificationView(
            viewModel: VerificationViewModel(
                dependencies: VerificationDependencies(
                    analytics: NoopAnalytics(),
                    logger: ConsoleLogger(),
                    service: MockVerificationService(),
                    provider: MockVerificationProvider()
                )
            )
        )
    }
}
#endif

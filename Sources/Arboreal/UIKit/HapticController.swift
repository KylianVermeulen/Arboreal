import UIKit

@MainActor
final class HapticController {
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?

    private let configuration: HapticConfiguration

    init(configuration: HapticConfiguration) {
        self.configuration = configuration
    }

    func prepare() {
        if configuration.dragStartEnabled || configuration.dropEnabled {
            impactGenerator = UIImpactFeedbackGenerator(style: .medium)
            impactGenerator?.prepare()
        }
        if configuration.hoverOverTargetEnabled {
            selectionGenerator = UISelectionFeedbackGenerator()
            selectionGenerator?.prepare()
        }
        if configuration.errorEnabled {
            notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator?.prepare()
        }
    }

    func fireDragStart() {
        guard configuration.dragStartEnabled else { return }
        impactGenerator?.impactOccurred()
        impactGenerator?.prepare()
    }

    func fireDrop() {
        guard configuration.dropEnabled else { return }
        impactGenerator?.impactOccurred()
    }

    func fireHover() {
        guard configuration.hoverOverTargetEnabled else { return }
        selectionGenerator?.selectionChanged()
        selectionGenerator?.prepare()
    }

    func fireCancel() {
        guard configuration.dropEnabled else { return }
        impactGenerator?.impactOccurred(intensity: 0.5)
    }

    func fireError() {
        guard configuration.errorEnabled else { return }
        notificationGenerator?.notificationOccurred(.error)
    }

    func tearDown() {
        impactGenerator = nil
        selectionGenerator = nil
        notificationGenerator = nil
    }
}

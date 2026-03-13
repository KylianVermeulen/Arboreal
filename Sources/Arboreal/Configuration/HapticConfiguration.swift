/// Controls which haptic feedback events are enabled during drag-and-drop.
public struct HapticConfiguration: Sendable {
    /// Haptic on drag start.
    public var dragStartEnabled: Bool
    /// Haptic on successful drop.
    public var dropEnabled: Bool
    /// Haptic when hovering over a valid drop target.
    public var hoverOverTargetEnabled: Bool
    /// Haptic on forbidden drop or error.
    public var errorEnabled: Bool

    public init(
        dragStartEnabled: Bool = true,
        dropEnabled: Bool = true,
        hoverOverTargetEnabled: Bool = true,
        errorEnabled: Bool = true
    ) {
        self.dragStartEnabled = dragStartEnabled
        self.dropEnabled = dropEnabled
        self.hoverOverTargetEnabled = hoverOverTargetEnabled
        self.errorEnabled = errorEnabled
    }

    /// All haptics enabled.
    public static let `default` = HapticConfiguration()
    /// All haptics disabled.
    public static let none = HapticConfiguration(
        dragStartEnabled: false,
        dropEnabled: false,
        hoverOverTargetEnabled: false,
        errorEnabled: false
    )
}

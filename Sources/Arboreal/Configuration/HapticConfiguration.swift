public struct HapticConfiguration: Sendable {
    public var dragStartEnabled: Bool
    public var dropEnabled: Bool
    public var hoverOverTargetEnabled: Bool
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

    public static let `default` = HapticConfiguration()
    public static let none = HapticConfiguration(
        dragStartEnabled: false,
        dropEnabled: false,
        hoverOverTargetEnabled: false,
        errorEnabled: false
    )
}

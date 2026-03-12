import SwiftUI

public struct TreeDragDropConfiguration<Content: TreeNodeContent> {
    // MARK: - Row Sizing
    public var rowHeight: CGFloat
    public var indentationWidth: CGFloat

    // MARK: - Drag Behavior
    public var dragEnabled: Bool
    public var multiSelectDragEnabled: Bool
    public var canDrag: (@MainActor @Sendable (Content) -> Bool)?
    public var dragPreview: (@MainActor @Sendable (Content, Int) -> AnyView)?
    public var multiItemDragPreview: (@MainActor @Sendable ([Content]) -> AnyView)?
    public var liftAnimationProvider: (@MainActor @Sendable (any UIDragAnimating) -> Void)?

    // MARK: - Drop Behavior
    public var dropEnabled: Bool
    public var canDropIntoContainersOnly: Bool
    public var autoExpandDelay: TimeInterval
    public var canDropIntoSection: (@MainActor @Sendable (Content, DragPayload<Content>) -> Bool)?
    public var canDropBetween: (@MainActor @Sendable (Content?, Content?, DragPayload<Content>) -> Bool)?

    // MARK: - Drop Indicator
    public var dropPreviewTheme: DropPreviewTheme

    // MARK: - Haptics
    public var hapticConfiguration: HapticConfiguration

    // MARK: - Callbacks
    public var onDragStarted: (@MainActor @Sendable (DragPayload<Content>) -> Void)?
    public var onDropCompleted: (@MainActor @Sendable (DragPayload<Content>, DropTarget<Content>) -> Void)?
    public var onDragCancelled: (@MainActor @Sendable () -> Void)?
    public var canAcceptDrop: (@MainActor @Sendable (DragPayload<Content>, DropTarget<Content>) -> Bool)?
    public var onReorder: (@MainActor @Sendable ([TreeNode<Content>]) -> Void)?
    public var dropAnimationProvider: (@MainActor @Sendable (any UIDragAnimating) -> Void)?

    public init(
        rowHeight: CGFloat = 44,
        indentationWidth: CGFloat = 20,
        dragEnabled: Bool = true,
        multiSelectDragEnabled: Bool = true,
        dropEnabled: Bool = true,
        canDropIntoContainersOnly: Bool = false,
        autoExpandDelay: TimeInterval = 0.8,
        dropPreviewTheme: DropPreviewTheme = .default,
        hapticConfiguration: HapticConfiguration = .default
    ) {
        self.rowHeight = rowHeight
        self.indentationWidth = indentationWidth
        self.dragEnabled = dragEnabled
        self.multiSelectDragEnabled = multiSelectDragEnabled
        self.dropEnabled = dropEnabled
        self.canDropIntoContainersOnly = canDropIntoContainersOnly
        self.autoExpandDelay = autoExpandDelay
        self.dropPreviewTheme = dropPreviewTheme
        self.hapticConfiguration = hapticConfiguration
    }
}

extension TreeDragDropConfiguration: Sendable where Content: Sendable {}

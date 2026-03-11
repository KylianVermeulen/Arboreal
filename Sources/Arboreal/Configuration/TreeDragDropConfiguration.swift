import SwiftUI

public struct TreeDragDropConfiguration<Content: TreeNodeContent> {
    // MARK: - Row Sizing
    public var rowHeight: CGFloat
    public var indentationWidth: CGFloat

    // MARK: - Drag Behavior
    public var dragEnabled: Bool
    public var multiSelectDragEnabled: Bool
    public var canDrag: (@MainActor (Content) -> Bool)?
    public var dragPreview: (@MainActor (Content, Int) -> AnyView)?
    public var multiItemDragPreview: (@MainActor ([Content]) -> AnyView)?
    public var liftAnimationProvider: (@MainActor (any UIDragAnimating) -> Void)?

    // MARK: - Drop Behavior
    public var dropEnabled: Bool
    public var canDropIntoContainersOnly: Bool
    public var autoExpandDelay: TimeInterval
    public var canDropIntoSection: (@MainActor (Content, DragPayload<Content>) -> Bool)?
    public var canDropBetween: (@MainActor (Content?, Content?, DragPayload<Content>) -> Bool)?

    // MARK: - Drop Indicator
    public var dropIndicatorStyle: DropIndicatorStyle

    // MARK: - Haptics
    public var hapticConfiguration: HapticConfiguration

    // MARK: - Callbacks
    public var onDragStarted: (@MainActor (DragPayload<Content>) -> Void)?
    public var onDropCompleted: (@MainActor (DragPayload<Content>, DropTarget<Content>) -> Void)?
    public var onDragCancelled: (@MainActor () -> Void)?
    public var canAcceptDrop: (@MainActor (DragPayload<Content>, DropTarget<Content>) -> Bool)?
    public var onReorder: (@MainActor ([TreeNode<Content>]) -> Void)?
    public var dropAnimationProvider: (@MainActor (any UIDragAnimating) -> Void)?

    public init(
        rowHeight: CGFloat = 44,
        indentationWidth: CGFloat = 20,
        dragEnabled: Bool = true,
        multiSelectDragEnabled: Bool = true,
        dropEnabled: Bool = true,
        canDropIntoContainersOnly: Bool = false,
        autoExpandDelay: TimeInterval = 0.8,
        dropIndicatorStyle: DropIndicatorStyle = .default,
        hapticConfiguration: HapticConfiguration = .default
    ) {
        self.rowHeight = rowHeight
        self.indentationWidth = indentationWidth
        self.dragEnabled = dragEnabled
        self.multiSelectDragEnabled = multiSelectDragEnabled
        self.dropEnabled = dropEnabled
        self.canDropIntoContainersOnly = canDropIntoContainersOnly
        self.autoExpandDelay = autoExpandDelay
        self.dropIndicatorStyle = dropIndicatorStyle
        self.hapticConfiguration = hapticConfiguration
    }
}

extension TreeDragDropConfiguration: Sendable where Content: Sendable {}

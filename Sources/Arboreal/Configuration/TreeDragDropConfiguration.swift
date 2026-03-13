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
    public var restrictDropToContainers: Bool
    public var canDropIntoSection: (@MainActor @Sendable (Content, DragPayload<Content>) -> Bool)?
    public var canDropBetween: (@MainActor @Sendable (Content?, Content?, DragPayload<Content>) -> Bool)?

    // MARK: - Drop Indicator
    public var dropPreviewTheme: DropPreviewTheme

    // MARK: - Floating Drag View
    public var floatingDragBackgroundColor: UIColor

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
        restrictDropToContainers: Bool = false,
        dropPreviewTheme: DropPreviewTheme = .default,
        floatingDragBackgroundColor: UIColor = UIColor(red: 0x1A/255.0, green: 0x40/255.0, blue: 0x78/255.0, alpha: 1),
        hapticConfiguration: HapticConfiguration = .default,
        canDrag: (@MainActor @Sendable (Content) -> Bool)? = nil,
        onReorder: (@MainActor @Sendable ([TreeNode<Content>]) -> Void)? = nil,
        onDropCompleted: (@MainActor @Sendable (DragPayload<Content>, DropTarget<Content>) -> Void)? = nil
    ) {
        self.rowHeight = rowHeight
        self.indentationWidth = indentationWidth
        self.dragEnabled = dragEnabled
        self.multiSelectDragEnabled = multiSelectDragEnabled
        self.dropEnabled = dropEnabled
        self.restrictDropToContainers = restrictDropToContainers
        self.dropPreviewTheme = dropPreviewTheme
        self.floatingDragBackgroundColor = floatingDragBackgroundColor
        self.hapticConfiguration = hapticConfiguration
        self.canDrag = canDrag
        self.onReorder = onReorder
        self.onDropCompleted = onDropCompleted
    }
}

extension TreeDragDropConfiguration: Sendable where Content: Sendable {}

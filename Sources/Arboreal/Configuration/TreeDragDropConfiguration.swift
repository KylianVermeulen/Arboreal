import SwiftUI

/// Configuration for the drag-and-drop behavior and appearance of a ``TreeDragDropView``.
public struct TreeDragDropConfiguration<Content: TreeNodeContent> {
    // MARK: - Row Sizing

    /// The height of each row in points. Defaults to 44.
    public var rowHeight: CGFloat
    /// The horizontal offset in points applied per depth level. Defaults to 20.
    public var indentationWidth: CGFloat

    // MARK: - Drag Behavior

    /// Whether dragging is enabled. Defaults to `true`.
    public var dragEnabled: Bool
    /// Whether multi-selection dragging is enabled. Defaults to `true`.
    public var multiSelectDragEnabled: Bool
    /// Optional per-item predicate controlling whether a specific node can be dragged.
    public var canDrag: (@MainActor @Sendable (Content) -> Bool)?

    // MARK: - Drop Behavior

    /// Whether dropping is enabled. Defaults to `true`.
    public var dropEnabled: Bool
    /// When `true`, non-container nodes cannot be dropped at root level and must remain inside a container. Defaults to `false`.
    public var restrictDropToContainers: Bool
    /// Optional predicate controlling whether a payload can be dropped into a specific section.
    public var canDropIntoSection: (@MainActor @Sendable (Content, DragPayload<Content>) -> Bool)?
    /// Optional predicate controlling whether a payload can be dropped between two nodes.
    /// The first parameter is the node before the drop position (or `nil` at the start),
    /// and the second is the node after (or `nil` at the end).
    public var canDropBetween: (@MainActor @Sendable (Content?, Content?, DragPayload<Content>) -> Bool)?

    // MARK: - Drop Indicator

    /// Theme for the drop preview indicator shown during a drag. Defaults to ``DropPreviewTheme/default``.
    public var dropPreviewTheme: DropPreviewTheme

    // MARK: - Floating Drag View

    /// Background color for the floating drag view that follows the user's finger.
    public var floatingDragBackgroundColor: UIColor

    // MARK: - Haptics

    /// Haptic feedback configuration. Defaults to ``HapticConfiguration/default``.
    public var hapticConfiguration: HapticConfiguration

    // MARK: - Callbacks

    /// Called when a drag operation begins.
    public var onDragStarted: (@MainActor @Sendable (DragPayload<Content>) -> Void)?
    /// Called when a drop completes successfully.
    public var onDropCompleted: (@MainActor @Sendable (DragPayload<Content>, DropTarget<Content>) -> Void)?
    /// Called when a drag operation is cancelled.
    public var onDragCancelled: (@MainActor @Sendable () -> Void)?
    /// Optional final gate to accept or reject a drop at a specific target.
    public var canAcceptDrop: (@MainActor @Sendable (DragPayload<Content>, DropTarget<Content>) -> Bool)?
    /// Called after the tree has been mutated by a drop, with the new tree.
    public var onReorder: (@MainActor @Sendable ([TreeNode<Content>]) -> Void)?

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

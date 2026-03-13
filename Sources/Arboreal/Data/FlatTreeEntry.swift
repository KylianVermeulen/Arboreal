/// A flattened representation of a tree node, used for layout.
///
/// Produced by ``Array/flattened(expansionState:)`` from a `[TreeNode]` array.
/// Each entry carries enough context for the UI to render a single row.
public struct FlatTreeEntry<Content: TreeNodeContent>: Identifiable, Sendable {
    /// The node's unique identifier.
    public var id: Content.ID
    /// The user-defined content.
    public var content: Content
    /// The indentation depth: 0 for root nodes, 1 for children.
    public var depth: Int
    /// The identifier of the parent node, or `nil` for root nodes.
    public var parentID: Content.ID?
    /// The index of this node among its siblings.
    public var indexInParent: Int
    /// Whether this node has children.
    public var hasChildren: Bool
    /// Whether this node's children are currently visible.
    public var isExpanded: Bool
    /// Whether this node is the last sibling at its depth.
    public var isLastChild: Bool
}

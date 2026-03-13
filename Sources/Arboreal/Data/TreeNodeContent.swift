/// A protocol that tree node content must conform to.
///
/// Conforming types represent the user-defined data stored in each ``TreeNode``.
/// They must be `Identifiable`, `Hashable`, and `Sendable`.
public protocol TreeNodeContent: Identifiable, Hashable, Sendable where ID: Sendable {
    /// Whether this content represents a container (section) that can hold children.
    ///
    /// Defaults to `false`. Override to return `true` for nodes that should act as collapsible sections.
    var isContainer: Bool { get }
}

extension TreeNodeContent {
    public var isContainer: Bool { false }
}

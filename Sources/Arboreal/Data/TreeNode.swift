/// A node in a tree structure with a maximum depth of 1.
///
/// Root nodes (depth 0) can have children, but children (depth 1) cannot.
/// Grandchildren are automatically stripped during construction.
public struct TreeNode<Content: TreeNodeContent>: Identifiable, Sendable {
    public var id: Content.ID
    public var content: Content
    public var children: [TreeNode<Content>]

    /// The number of direct children.
    public var childCount: Int { children.count }

    /// Creates a tree node with the given content and optional children.
    ///
    /// - Parameters:
    ///   - content: The user-defined content for this node.
    ///   - children: Child nodes. Any grandchildren are stripped to enforce max depth 1.
    public init(content: Content, children: [TreeNode<Content>] = []) {
        self.id = content.id
        self.content = content
        // Enforce max depth 1: children cannot have children
        if children.allSatisfy({ $0.children.isEmpty }) {
            self.children = children
        } else {
            self.children = children.map { child in
                TreeNode(content: child.content, children: [])
            }
        }
    }
}

extension TreeNode: Hashable {
    public static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

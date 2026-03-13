public struct TreeNode<Content: TreeNodeContent>: Identifiable, Sendable {
    public var id: Content.ID
    public var content: Content
    public var children: [TreeNode<Content>]

    public var descendantCount: Int { children.count }

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

public struct TreeNode<Content: TreeNodeContent>: Identifiable, Sendable {
    public var id: Content.ID
    public var content: Content
    public var children: [TreeNode<Content>]

    public var descendantCount: Int {
        children.reduce(0) { $0 + 1 + $1.descendantCount }
    }

    public init(content: Content, children: [TreeNode<Content>] = []) {
        self.id = content.id
        self.content = content
        self.children = children
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

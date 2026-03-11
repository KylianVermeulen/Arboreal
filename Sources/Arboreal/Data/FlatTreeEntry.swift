public struct FlatTreeEntry<Content: TreeNodeContent>: Identifiable, Sendable {
    public var id: Content.ID
    public var content: Content
    public var depth: Int
    public var parentID: Content.ID?
    public var indexInParent: Int
    public var hasChildren: Bool
    public var isExpanded: Bool
}

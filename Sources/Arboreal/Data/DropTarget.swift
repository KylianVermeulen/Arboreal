public enum DropTarget<Content: TreeNodeContent>: Sendable, Equatable {
    /// Insert at a specific index among the children of a parent node.
    /// `parentID` is nil for root-level insertion.
    case atIndex(parentID: Content.ID?, index: Int)

    /// Drop into a collapsed container (appends to its children).
    case intoSection(Content.ID)
}

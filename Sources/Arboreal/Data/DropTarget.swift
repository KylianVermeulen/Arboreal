public enum DropTarget<Content: TreeNodeContent>: Sendable, Equatable {
    case before(Content.ID)
    case after(Content.ID)
    case intoSection(Content.ID)
    case rootLevel(index: Int)
}

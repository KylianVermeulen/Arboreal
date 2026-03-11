public enum DropTarget<Content: TreeNodeContent>: Sendable, Equatable {
    case before(Content.ID)
    case after(Content.ID)
    case into(Content.ID)
    case rootLevel(index: Int)
}

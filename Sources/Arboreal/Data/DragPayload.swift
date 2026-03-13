public enum DragPayload<Content: TreeNodeContent>: Sendable {
    case singleItem(Content.ID)
    case multipleItems(Set<Content.ID>)
    case section(Content.ID)

    public var draggedIDs: Set<Content.ID> {
        switch self {
        case .singleItem(let id), .section(let id): [id]
        case .multipleItems(let ids): ids
        }
    }
}

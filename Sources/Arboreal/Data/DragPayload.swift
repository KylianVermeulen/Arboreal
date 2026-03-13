/// Describes what is being dragged in a drag-and-drop operation.
public enum DragPayload<Content: TreeNodeContent>: Sendable {
    /// A single leaf node is being dragged.
    case singleItem(Content.ID)
    /// Multiple selected nodes are being dragged together.
    case multipleItems(Set<Content.ID>)
    /// An entire section (container node) is being dragged.
    case section(Content.ID)

    /// The set of all node identifiers involved in this drag operation.
    public var draggedIDs: Set<Content.ID> {
        switch self {
        case .singleItem(let id), .section(let id): [id]
        case .multipleItems(let ids): ids
        }
    }
}

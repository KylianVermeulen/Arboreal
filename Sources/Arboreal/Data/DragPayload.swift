public enum DragPayload<Content: TreeNodeContent>: Sendable {
    case singleItem(Content.ID)
    case multipleItems(Set<Content.ID>)
    case section(Content.ID)
}

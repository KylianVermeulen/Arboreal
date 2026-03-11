@MainActor
enum DragState<Content: TreeNodeContent>: Sendable where Content: Sendable {
    case idle
    case lifting(itemID: Content.ID)
    case dragging(payload: DragPayload<Content>, currentTarget: DropTarget<Content>?)
    case dropping(payload: DragPayload<Content>, target: DropTarget<Content>)
    case cancelling

    var isDragging: Bool {
        switch self {
        case .dragging: true
        default: false
        }
    }

    var payload: DragPayload<Content>? {
        switch self {
        case .dragging(let payload, _), .dropping(let payload, _):
            payload
        default:
            nil
        }
    }

    var currentTarget: DropTarget<Content>? {
        switch self {
        case .dragging(_, let target):
            target
        default:
            nil
        }
    }
}

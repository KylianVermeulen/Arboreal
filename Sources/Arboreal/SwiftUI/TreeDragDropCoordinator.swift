import UIKit
import SwiftUI

@MainActor
public final class TreeDragDropCoordinator<Content: TreeNodeContent, CellContent: View>: NSObject, UIDragInteractionDelegate, UIDropInteractionDelegate where Content: Sendable, Content.ID: Sendable {

    // MARK: - State

    var tree: [TreeNode<Content>] = []
    var selectedIDs: Set<Content.ID> = []
    var expansionState: ExpansionState<Content.ID>
    weak var containerView: TreeContainerView<Content>?

    var generation: Int = 0
    var isPerformingDrop = false

    private var hapticController: HapticController
    private var autoExpandTimer: Timer?
    private var autoExpandTargetID: Content.ID?
    private var view: TreeDragDropView<Content, CellContent>

    // MARK: - Init

    init(view: TreeDragDropView<Content, CellContent>) {
        self.view = view
        self.tree = view.tree
        self.selectedIDs = view.selectedIDs
        self.expansionState = view.expansionState
        self.hapticController = HapticController(configuration: view.configuration.hapticConfiguration)
        super.init()
    }

    // MARK: - Entry Updates

    func updateEntries() {
        let entries = flattenTree(tree, expansionState: expansionState.expandedIDs)
        containerView?.updateEntries(entries)
    }

    // MARK: - UIDragInteractionDelegate

    public func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] {
        guard let containerView else { return [] }

        let location = session.location(in: containerView)
        guard let entry = containerView.entry(at: location) else { return [] }

        hapticController.prepare()

        let payload: DragPayload<Content>
        if selectedIDs.contains(entry.id) && selectedIDs.count > 1 {
            payload = .multipleItems(selectedIDs)
        } else {
            payload = .singleItem(entry.id)
        }

        containerView.transitionDragState(to: .lifting(itemID: entry.id))

        let itemProvider = NSItemProvider()
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = payload

        hapticController.fireDragStart()
        view.configuration.onDragStarted?(payload)

        containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))

        return [dragItem]
    }

    public func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: any UIDragSession) -> UITargetedDragPreview? {
        guard let containerView else { return nil }
        let location = session.location(in: containerView)
        guard let entry = containerView.entry(at: location) else { return nil }

        if let customPreview = view.configuration.dragPreview {
            let previewView = customPreview(entry.content, entry.depth)
            let hostingController = UIHostingController(rootView: previewView)
            hostingController.view.sizeToFit()
            let center = CGPoint(x: hostingController.view.bounds.midX, y: hostingController.view.bounds.midY)
            let target = UIDragPreviewTarget(container: containerView, center: center)
            return UITargetedDragPreview(view: hostingController.view, parameters: UIDragPreviewParameters(), target: target)
        }

        return nil
    }

    public func dragInteraction(_ interaction: UIDragInteraction, sessionDidEnd session: any UIDragSession) {
        containerView?.transitionDragState(to: .idle)
        hapticController.tearDown()
        cancelAutoExpandTimer()
        view.configuration.onDragCancelled?()
    }

    // MARK: - UIDropInteractionDelegate

    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: any UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: any UIDropSession) -> UIDropProposal {
        guard let containerView else { return UIDropProposal(operation: .cancel) }

        let location = session.location(in: containerView)
        let target = containerView.resolveDropTarget(at: location)

        guard let target,
              let dragItem = session.items.first,
              let payload = dragItem.localObject as? DragPayload<Content> else {
            if let existingPayload = containerView.dragState.payload {
                containerView.transitionDragState(to: .dragging(payload: existingPayload, currentTarget: nil))
            } else {
                containerView.transitionDragState(to: .idle)
            }
            cancelAutoExpandTimer()
            return UIDropProposal(operation: .cancel)
        }

        let draggedIDs = draggedIDs(from: payload)

        // Check cycle prevention
        guard canDrop(in: tree, draggedIDs: draggedIDs, onto: target) else {
            hapticController.fireError()
            return UIDropProposal(operation: .forbidden)
        }

        // Check custom acceptance
        if let canAccept = view.configuration.canAcceptDrop, !canAccept(payload, target) {
            return UIDropProposal(operation: .forbidden)
        }

        // Update drag state with new target
        let previousTarget = containerView.dragState.currentTarget
        containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: target))

        // Fire hover haptic on target change
        if previousTarget != target {
            hapticController.fireHover()
        }

        // Auto-expand handling
        if case .into(let targetID) = target {
            if autoExpandTargetID != targetID {
                cancelAutoExpandTimer()
                autoExpandTargetID = targetID
                autoExpandTimer = Timer.scheduledTimer(withTimeInterval: view.configuration.autoExpandDelay, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.expansionState.expand(targetID)
                        self?.updateEntries()
                    }
                }
            }
        } else {
            cancelAutoExpandTimer()
        }

        return UIDropProposal(operation: .move)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: any UIDropSession) {
        guard let containerView,
              let dragItem = session.items.first,
              let payload = dragItem.localObject as? DragPayload<Content>,
              let target = containerView.dragState.currentTarget else {
            return
        }

        containerView.transitionDragState(to: .dropping(payload: payload, target: target))

        isPerformingDrop = true

        let draggedIDs = draggedIDs(from: payload)

        // Perform the mutation
        let newTree = moveNodes(in: tree, ids: draggedIDs, to: target)
        view.$tree.wrappedValue = newTree
        tree = newTree

        hapticController.fireDrop()
        view.configuration.onDropCompleted?(payload, target)

        // Update the view
        updateEntries()

        isPerformingDrop = false
        containerView.transitionDragState(to: .idle)
        cancelAutoExpandTimer()
        hapticController.tearDown()
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: any UIDropSession) {
        if let existingPayload = containerView?.dragState.payload {
            containerView?.transitionDragState(to: .dragging(payload: existingPayload, currentTarget: nil))
        } else {
            containerView?.transitionDragState(to: .idle)
        }
        cancelAutoExpandTimer()
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: any UIDropSession) {
        containerView?.transitionDragState(to: .idle)
        cancelAutoExpandTimer()
        hapticController.tearDown()
    }

    // MARK: - Helpers

    private func draggedIDs(from payload: DragPayload<Content>) -> Set<Content.ID> {
        switch payload {
        case .singleItem(let id): [id]
        case .multipleItems(let ids): ids
        case .section(let id): [id]
        }
    }

    private func cancelAutoExpandTimer() {
        autoExpandTimer?.invalidate()
        autoExpandTimer = nil
        autoExpandTargetID = nil
    }
}

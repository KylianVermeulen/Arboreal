import UIKit
import SwiftUI

/// Coordinator that bridges UIKit drag-and-drop interactions to the SwiftUI tree binding.
///
/// Created internally by ``TreeDragDropView``. Public only because UIKit delegate
/// conformances require it.
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
    private var view: TreeDragDropView<Content, CellContent>
    private weak var liftingCell: UIView?

    // Floating drag view (follows finger)
    private var floatingDragView: UIView?
    private var dragTouchOffset: CGPoint = .zero
    private var originalCellFrameInWindow: CGRect = .zero

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
        let entries = tree.flattened(expansionState: expansionState.expandedIDs)
        containerView?.updateEntries(entries)
    }

    // MARK: - UIDragInteractionDelegate

    public func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] {
        guard let containerView else { return [] }

        let location = session.location(in: containerView)
        guard let entry = containerView.entry(at: location) else { return [] }

        // Check per-item drag permission
        if let canDrag = view.configuration.canDrag, !canDrag(entry.content) {
            return []
        }

        hapticController.prepare()

        let payload: DragPayload<Content>
        if selectedIDs.contains(entry.id) && selectedIDs.count > 1 {
            payload = .multipleItems(selectedIDs)
        } else {
            payload = .singleItem(entry.id)
        }

        // Snapshot the cell and hide it before preview layout kicks in
        if let index = containerView.entryIndex(at: location) {
            liftingCell = containerView.cellForEntry(at: index)
        }
        if let cell = liftingCell, let window = containerView.window {
            createFloatingDragView(for: cell, in: window, touchLocation: session.location(in: window))
            cell.isHidden = true
        }

        containerView.transitionDragState(to: .lifting(itemID: entry.id, payload: payload))

        let itemProvider = NSItemProvider()
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = payload

        hapticController.fireDragStart()
        view.configuration.onDragStarted?(payload)

        containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))

        return [dragItem]
    }

    public func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: any UIDragSession) -> UITargetedDragPreview? {
        // Floating view was already created in itemsForBeginning
        return nil
    }

    public func dragInteraction(_ interaction: UIDragInteraction, willAnimateLiftWith animator: any UIDragAnimating, session: any UIDragSession) {
        // Hide the original cell immediately; the floating view is the visual representation
        liftingCell?.isHidden = true

        // If the lift is canceled (released without dragging), clean up the floating view
        animator.addCompletion { position in
            guard position != .end else { return }
            self.removeFloatingDragView()
            self.liftingCell?.isHidden = false
            self.liftingCell?.transform = .identity
            self.liftingCell?.alpha = 1
            self.liftingCell = nil
            self.containerView?.transitionDragState(to: .idle)
            self.updateEntries()
        }
    }

    public func dragInteraction(_ interaction: UIDragInteraction, session: any UIDragSession, didEndWith operation: UIDropOperation) {
        // Animate floating view back to original position, then remove
        if let floating = floatingDragView {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                floating.transform = .identity
                floating.frame = self.originalCellFrameInWindow
                floating.layer.shadowOpacity = 0
            } completion: { _ in
                floating.removeFromSuperview()
            }
            floatingDragView = nil
        }

        // Restore lifting cell
        liftingCell?.isHidden = false
        liftingCell?.transform = .identity
        liftingCell?.alpha = 1
        liftingCell = nil

        containerView?.transitionDragState(to: .idle)

        // Force layout refresh to ensure all cells are visible after drag cancel
        updateEntries()

        hapticController.fireCancel()
        hapticController.tearDown()
        view.configuration.onDragCancelled?()
    }

    public func dragInteraction(_ interaction: UIDragInteraction, item: UIDragItem, willAnimateCancelWith animator: any UIDragAnimating) {
        let cell = liftingCell
        animator.addAnimations {
            cell?.alpha = 1
            cell?.transform = .identity
        }
        animator.addCompletion { _ in
            cell?.isHidden = false
        }
    }

    // MARK: - UIDropInteractionDelegate

    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: any UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: any UIDropSession) -> UIDropProposal {
        guard let containerView else { return UIDropProposal(operation: .cancel) }

        let location = session.location(in: containerView)
        let payload = session.items.first?.localObject as? DragPayload<Content>
        let target = containerView.resolveDropTarget(at: location, payload: payload)

        // Update floating view position
        if let floating = floatingDragView, let window = containerView.window {
            let touchInWindow = session.location(in: window)
            floating.center = CGPoint(
                x: touchInWindow.x + dragTouchOffset.x,
                y: touchInWindow.y + dragTouchOffset.y
            )
        }

        guard let target, let payload else {
            if let existingPayload = containerView.dragState.payload {
                containerView.transitionDragState(to: .dragging(payload: existingPayload, currentTarget: nil))
            } else {
                containerView.transitionDragState(to: .idle)
            }
            return UIDropProposal(operation: .cancel)
        }

        let draggedIDs = payload.draggedIDs
        let previousTarget = containerView.dragState.currentTarget

        // Early out if target hasn't changed — avoid redundant work
        if previousTarget == target {
            return UIDropProposal(operation: .move)
        }

        // Dropping onto the dragged item or any of its descendants is a no-op, not an error
        let targetRefersToSelf: Bool
        switch target {
        case .atIndex(let parentID, let index):
            if let parentID, (draggedIDs.contains(parentID) || draggedIDs.contains(where: { tree.isDescendant(parentID, of: $0) })) {
                targetRefersToSelf = true
            } else {
                // Check if the child at this index (or index-1) is a dragged node
                let sibs = tree.siblings(ofParent: parentID)
                let refersAtIndex = index < sibs.count && draggedIDs.contains(sibs[index].id)
                let refersBeforeIndex = index > 0 && index <= sibs.count && draggedIDs.contains(sibs[index - 1].id)
                targetRefersToSelf = refersAtIndex || refersBeforeIndex
            }
        case .intoSection(let id):
            targetRefersToSelf = draggedIDs.contains(id)
                || draggedIDs.contains(where: { tree.isDescendant(id, of: $0) })
        }

        if targetRefersToSelf {
            containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: target))
            return UIDropProposal(operation: .move)
        }

        // Check cycle prevention / depth enforcement
        guard tree.canDrop(draggedIDs: draggedIDs, onto: target) else {
            containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))
            return UIDropProposal(operation: .forbidden)
        }

        // Restrict non-container nodes from being dropped at root level
        if view.configuration.restrictDropToContainers,
           case .atIndex(parentID: nil, _) = target {
            let hasNonContainer = draggedIDs.contains { id in
                guard let node = tree.findNode(id: id) else { return false }
                return !node.content.isContainer
            }
            if hasNonContainer {
                containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))
                return UIDropProposal(operation: .forbidden)
            }
        }

        // Check granular drop validation
        if let canDropInto = view.configuration.canDropIntoSection,
           case .intoSection(let parentID) = target,
           let parentNode = tree.findNode(id: parentID) {
            if !canDropInto(parentNode.content, payload) {
                containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))
                return UIDropProposal(operation: .forbidden)
            }
        }

        if let canDropBetween = view.configuration.canDropBetween,
           case .atIndex(let parentID, let index) = target {
            let sibs = tree.siblings(ofParent: parentID)
            let before = index > 0 ? sibs[index - 1].content : nil
            let after = index < sibs.count ? sibs[index].content : nil
            if !canDropBetween(before, after, payload) {
                containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))
                return UIDropProposal(operation: .forbidden)
            }
        }

        // Check custom acceptance
        if let canAccept = view.configuration.canAcceptDrop, !canAccept(payload, target) {
            containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: nil))
            return UIDropProposal(operation: .forbidden)
        }

        // Update drag state with new target
        containerView.transitionDragState(to: .dragging(payload: payload, currentTarget: target))
        hapticController.fireHover()


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

        let draggedIDs = payload.draggedIDs

        // Perform the mutation
        let newTree = tree.movingNodes(ids: draggedIDs, to: target)
        tree = newTree

        // Remove floating drag view
        removeFloatingDragView()

        // Restore lifting cell
        liftingCell?.isHidden = false
        liftingCell?.transform = .identity
        liftingCell?.alpha = 1
        liftingCell = nil

        hapticController.fireDrop()
        view.configuration.onDropCompleted?(payload, target)
        view.configuration.onReorder?(newTree)

        // Animate from preview positions to final layout
        let newEntries = newTree.flattened(expansionState: expansionState.expandedIDs)
        containerView.animateDropCompletion(with: newEntries, draggedIDs: draggedIDs)

        isPerformingDrop = false
        containerView.transitionDragState(to: .idle)
        hapticController.tearDown()
    }

    public func dropInteraction(_ interaction: UIDropInteraction, previewForDropping item: UIDragItem, withDefault defaultPreview: UITargetedDragPreview) -> UITargetedDragPreview? {
        guard let containerView,
              let target = containerView.dragState.currentTarget else {
            return defaultPreview
        }

        let targetFrame = containerView.frameForDropTarget(target)
        let newTarget = UIDragPreviewTarget(
            container: containerView,
            center: CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        )
        return defaultPreview.retargetedPreview(with: newTarget)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: any UIDropSession) {
        removeFloatingDragView()
        if let existingPayload = containerView?.dragState.payload {
            containerView?.transitionDragState(to: .dragging(payload: existingPayload, currentTarget: nil))
        } else {
            containerView?.transitionDragState(to: .idle)
        }
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: any UIDropSession) {
        removeFloatingDragView()
        containerView?.transitionDragState(to: .idle)
        hapticController.tearDown()
    }

    // MARK: - Floating Drag View

    private func createFloatingDragView(for cell: UIView, in window: UIWindow, touchLocation: CGPoint) {
        let cellFrameInWindow = cell.convert(cell.bounds, to: window)
        originalCellFrameInWindow = cellFrameInWindow

        // Compute offset from touch to cell center so the cell stays anchored to the finger
        dragTouchOffset = CGPoint(
            x: cellFrameInWindow.midX - touchLocation.x,
            y: cellFrameInWindow.midY - touchLocation.y
        )

        let snapshot = cell.snapshotView(afterScreenUpdates: false) ?? UIView()
        snapshot.frame = cellFrameInWindow
        snapshot.isUserInteractionEnabled = false

        snapshot.backgroundColor = view.configuration.floatingDragBackgroundColor
        snapshot.layer.cornerRadius = 10
        snapshot.clipsToBounds = false

        // Shadow
        snapshot.layer.shadowColor = UIColor.black.cgColor
        snapshot.layer.shadowOpacity = 0.25
        snapshot.layer.shadowRadius = 12
        snapshot.layer.shadowOffset = CGSize(width: 0, height: 4)

        window.addSubview(snapshot)
        floatingDragView = snapshot

        // Slight scale-up on creation
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            snapshot.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        }
    }

    private func removeFloatingDragView() {
        floatingDragView?.removeFromSuperview()
        floatingDragView = nil
    }
}

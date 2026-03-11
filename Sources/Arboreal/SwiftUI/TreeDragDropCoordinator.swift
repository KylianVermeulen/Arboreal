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
        let entries = flattenTree(tree, expansionState: expansionState.expandedIDs)
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

        // Track the cell for lift animation
        if let index = containerView.entryIndex(at: location) {
            liftingCell = containerView.cellForEntry(at: index)
        }

        if let customPreview = view.configuration.dragPreview,
           let entry = containerView.entry(at: location) {
            let previewView = customPreview(entry.content, entry.depth)
            let hostingController = UIHostingController(rootView: previewView)
            hostingController.view.sizeToFit()
            let center = CGPoint(x: hostingController.view.bounds.midX, y: hostingController.view.bounds.midY)
            let target = UIDragPreviewTarget(container: containerView, center: center)
            return UITargetedDragPreview(view: hostingController.view, parameters: UIDragPreviewParameters(), target: target)
        }

        // Create floating snapshot and return invisible system preview
        if let cell = liftingCell, let window = containerView.window {
            createFloatingDragView(for: cell, in: window, touchLocation: session.location(in: window))
        }

//        // Return a 1x1 invisible preview to suppress UIKit's default
//        let invisible = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
//        invisible.backgroundColor = .clear
//        let params = UIDragPreviewParameters()
//        params.backgroundColor = .clear
//        let center = session.location(in: containerView)
//        let target = UIDragPreviewTarget(container: containerView, center: center)
//        return UITargetedDragPreview(view: invisible, parameters: params, target: target)
        return nil
    }

    public func dragInteraction(_ interaction: UIDragInteraction, willAnimateLiftWith animator: any UIDragAnimating, session: any UIDragSession) {
        // Allow consumer to customize lift animation
        if let customLift = view.configuration.liftAnimationProvider {
            customLift(animator)
            return
        }

        // Hide the original cell; the floating view is now the visual representation
        let cell = liftingCell
        animator.addCompletion { position in
            if position == .end {
                cell?.isHidden = true
            }
        }
    }

    public func dragInteraction(_ interaction: UIDragInteraction, sessionDidEnd session: any UIDragSession) {
        // Animate floating view back to original position, then remove
        if let floating = floatingDragView {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
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
        cancelAutoExpandTimer()
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
        let target = containerView.resolveDropTarget(at: location)

        // Update floating view position
        if let floating = floatingDragView, let window = containerView.window {
            let touchInWindow = session.location(in: window)
            floating.center = CGPoint(
                x: touchInWindow.x + dragTouchOffset.x,
                y: touchInWindow.y + dragTouchOffset.y
            )
        }

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

        // Check granular drop validation
        if let canDropInto = view.configuration.canDropIntoSection,
           case .intoSection(let parentID) = target,
           let parentNode = findNodeInTree(id: parentID) {
            if !canDropInto(parentNode.content, payload) {
                return UIDropProposal(operation: .forbidden)
            }
        }

        if let canDropBetween = view.configuration.canDropBetween {
            switch target {
            case .before(let id):
                let (prev, current) = neighborEntries(for: id)
                if !canDropBetween(prev?.content, current?.content, payload) {
                    return UIDropProposal(operation: .forbidden)
                }
            case .after(let id):
                let (current, next) = neighborEntries(after: id)
                if !canDropBetween(current?.content, next?.content, payload) {
                    return UIDropProposal(operation: .forbidden)
                }
            default:
                break
            }
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
        if case .intoSection(let targetID) = target {
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

        // Update the view
        updateEntries()

        isPerformingDrop = false
        containerView.transitionDragState(to: .idle)
        cancelAutoExpandTimer()
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
        cancelAutoExpandTimer()
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: any UIDropSession) {
        removeFloatingDragView()
        containerView?.transitionDragState(to: .idle)
        cancelAutoExpandTimer()
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

        // Lifted appearance
        snapshot.layer.shadowColor = UIColor.black.cgColor
        snapshot.layer.shadowOpacity = 0.2
        snapshot.layer.shadowRadius = 8
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

    private func findNodeInTree(id: Content.ID) -> TreeNode<Content>? {
        func find(in nodes: [TreeNode<Content>]) -> TreeNode<Content>? {
            for node in nodes {
                if node.id == id { return node }
                if let found = find(in: node.children) { return found }
            }
            return nil
        }
        return find(in: tree)
    }

    private func neighborEntries(for id: Content.ID) -> (before: FlatTreeEntry<Content>?, current: FlatTreeEntry<Content>?) {
        guard let containerView,
              let entries = containerView.currentEntries,
              let index = entries.firstIndex(where: { $0.id == id }) else {
            return (nil, nil)
        }
        let before = index > 0 ? entries[index - 1] : nil
        return (before, entries[index])
    }

    private func neighborEntries(after id: Content.ID) -> (current: FlatTreeEntry<Content>?, after: FlatTreeEntry<Content>?) {
        guard let containerView,
              let entries = containerView.currentEntries,
              let index = entries.firstIndex(where: { $0.id == id }) else {
            return (nil, nil)
        }
        let after = index < entries.count - 1 ? entries[index + 1] : nil
        return (entries[index], after)
    }
}

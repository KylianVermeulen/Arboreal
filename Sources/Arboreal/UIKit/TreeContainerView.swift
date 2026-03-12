import UIKit
import SwiftUI

@MainActor
public final class TreeContainerView<Content: TreeNodeContent>: UIScrollView
where Content: Sendable, Content.ID: Sendable {
    // MARK: - State

    private var flatEntries: [FlatTreeEntry<Content>] = []
    private var cellPool = ViewReusePool<TreeNodeCell>(factory: { TreeNodeCell() })
    private var dropIndicatorLayer = DropIndicatorLayer()
    private(set) var dragState: DragState<Content> = .idle
    private var activePreviewLayout: PreviewLayout<Content>?
    private var debugLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        l.numberOfLines = 0
        l.layer.zPosition = 9999
        return l
    }()

    // MARK: - Configuration

    var configuration: TreeDragDropConfiguration<Content> = .init()
    var cellContentProvider: (@MainActor (FlatTreeEntry<Content>) -> AnyView)?

    // MARK: - Public Accessors

    var currentEntries: [FlatTreeEntry<Content>]? { flatEntries.isEmpty ? nil : flatEntries }

    // MARK: - Layout Constants

    private var contentHeight: CGFloat { CGFloat(flatEntries.count) * configuration.rowHeight }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.addSublayer(dropIndicatorLayer)
        alwaysBounceVertical = true
        addSubview(debugLabel)
    }

    func installInteractions(dragDelegate: (any UIDragInteractionDelegate)?, dropDelegate: (any UIDropInteractionDelegate)?) {
        if configuration.dragEnabled, let dragDelegate {
            let dragInteraction = UIDragInteraction(delegate: dragDelegate)
            addInteraction(dragInteraction)
        }
        if configuration.dropEnabled, let dropDelegate {
            let dropInteraction = UIDropInteraction(delegate: dropDelegate)
            addInteraction(dropInteraction)
        }
    }

    // MARK: - Data Updates

    func updateEntries(_ newEntries: [FlatTreeEntry<Content>]) {
        // Skip layout updates during active drag to avoid visual jitter
        guard !dragState.isDragging else {
            flatEntries = newEntries
            return
        }

        let oldEntries = flatEntries
        flatEntries = newEntries

        // Use CollectionDifference for efficient updates
        let diff = newEntries.difference(from: oldEntries) { $0.id == $1.id }

        let removedIDs = Set(diff.removals.compactMap { change -> Content.ID? in
            if case .remove(_, let element, _) = change { return element.id }
            return nil
        })

        // Recycle removed cells
        for id in removedIDs {
            cellPool.recycle(for: AnyHashable(id))
        }

        // Update content size and layout
        contentSize = CGSize(width: bounds.width, height: contentHeight)
        layoutVisibleCells()
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        contentSize = CGSize(width: bounds.width, height: contentHeight)
        layoutVisibleCells()
    }

    private func layoutVisibleCells() {
        // During active drag with preview layout, use preview positions
        if let preview = activePreviewLayout, dragState.isDragging {
            layoutVisibleCellsWithPreview(preview)
            return
        }

        // Skip cell recycling during active drag to avoid jitter
        let isDragging = dragState.isDragging

        let visibleRect = CGRect(
            x: 0,
            y: contentOffset.y,
            width: bounds.width,
            height: bounds.height
        )

        let firstVisible = max(0, Int(floor(visibleRect.minY / configuration.rowHeight)))
        let lastVisible = min(
            flatEntries.count - 1, Int(ceil(visibleRect.maxY / configuration.rowHeight)))

        guard firstVisible <= lastVisible else {
            if !isDragging {
                cellPool.recycleAll(except: [])
            }
            return
        }

        var visibleKeys = Set<AnyHashable>()
        let provider = cellContentProvider

        for index in firstVisible...lastVisible {
            let entry = flatEntries[index]
            let key = AnyHashable(entry.id)
            visibleKeys.insert(key)

            let cell = cellPool.dequeue(for: key)

            let indent = CGFloat(entry.depth) * configuration.indentationWidth
            let cellFrame = CGRect(
                x: indent,
                y: CGFloat(index) * configuration.rowHeight,
                width: bounds.width - indent,
                height: configuration.rowHeight
            )

            // Reset visual state before setting frame — UIKit frame is
            // undefined when transform != .identity.
            cell.transform = .identity
            cell.alpha = 1
            cell.isHidden = false
            cell.frame = cellFrame

            if cell.superview == nil {
                addSubview(cell)
            }

            if let provider {
                cell.configure(with: provider(entry))
            }
        }

        // Recycle off-screen cells (skip during drag)
        if !isDragging {
            cellPool.recycleAll(except: visibleKeys)
        }
    }

    private func layoutVisibleCellsWithPreview(_ preview: PreviewLayout<Content>) {
        let provider = cellContentProvider

        for entry in flatEntries {
            let key = AnyHashable(entry.id)

            if preview.draggedIDs.contains(entry.id) {
                cellPool.cell(for: key)?.isHidden = true
                continue
            }

            guard let yPosition = preview.entryYPositions[entry.id] else { continue }

            // Check if within visible rect (with buffer)
            let visibleMinY = contentOffset.y - configuration.rowHeight
            let visibleMaxY = contentOffset.y + bounds.height + configuration.rowHeight
            guard yPosition + configuration.rowHeight > visibleMinY,
                  yPosition < visibleMaxY else { continue }

            let cell = cellPool.dequeue(for: key)
            let indent = CGFloat(entry.depth) * configuration.indentationWidth

            cell.transform = .identity
            cell.alpha = 1
            cell.isHidden = false
            cell.frame = CGRect(
                x: indent,
                y: yPosition,
                width: bounds.width - indent,
                height: configuration.rowHeight
            )

            if cell.superview == nil {
                addSubview(cell)
            }

            if let provider {
                cell.configure(with: provider(entry))
            }
        }
    }

    // MARK: - Hit Testing

    /// Returns the index of the entry at a given Y position. O(1).
    func entryIndex(at point: CGPoint) -> Int? {
        let index = Int(floor(point.y / configuration.rowHeight))
        guard index >= 0, index < flatEntries.count else { return nil }
        return index
    }

    func entry(at point: CGPoint) -> FlatTreeEntry<Content>? {
        guard let index = entryIndex(at: point) else { return nil }
        return flatEntries[index]
    }

    // MARK: - Cell Access

    func cellForEntry(at index: Int) -> TreeNodeCell? {
        guard index >= 0, index < flatEntries.count else { return nil }
        let key = AnyHashable(flatEntries[index].id)
        return cellPool.cell(for: key)
    }

    // MARK: - Drop Target Resolution

    func resolveDropTarget(at point: CGPoint) -> DropTarget<Content>? {
        guard let index = entryIndex(at: point) else {
            // Below all items - drop at root level
            return .rootLevel(index: flatEntries.count)
        }

        let entry = flatEntries[index]
        let rowTop = CGFloat(index) * configuration.rowHeight
        let relativeY = point.y - rowTop
        let fraction = relativeY / configuration.rowHeight

        let allowInto = !entry.isExpanded
            && (entry.hasChildren || (entry.content.isContainer && !configuration.canDropIntoContainersOnly))

        debugLabel.text = "idx=\(index) exp=\(entry.isExpanded) child=\(entry.hasChildren) cont=\(entry.content.isContainer) allow=\(allowInto)"
        debugLabel.sizeToFit()
        debugLabel.frame.origin = CGPoint(x: 8, y: contentOffset.y + 8)

        if allowInto {
            // For collapsed containers: top 25% = before, middle 50% = into, bottom 25% = after
            if fraction < 0.25 {
                return .before(entry.id)
            } else if fraction > 0.75 {
                return .after(entry.id)
            } else {
                return .intoSection(entry.id)
            }
        } else if entry.isExpanded, index + 1 < flatEntries.count {
            // For expanded containers: top 50% = before, bottom 50% = before first child
            if fraction < 0.5 {
                return .before(entry.id)
            } else {
                return .before(flatEntries[index + 1].id)
            }
        } else {
            // For leaves: top 50% = before, bottom 50% = after
            if fraction < 0.5 {
                return .before(entry.id)
            } else {
                return .after(entry.id)
            }
        }
    }

    // MARK: - Frame Calculations

    func frameForDropTarget(_ target: DropTarget<Content>) -> CGRect {
        switch target {
        case .before(let id):
            if let index = flatEntries.firstIndex(where: { $0.id == id }) {
                let y = CGFloat(index) * configuration.rowHeight
                return CGRect(x: 0, y: y, width: bounds.width, height: configuration.rowHeight)
            }
        case .after(let id):
            if let index = flatEntries.firstIndex(where: { $0.id == id }) {
                let y = CGFloat(index) * configuration.rowHeight
                return CGRect(x: 0, y: y, width: bounds.width, height: configuration.rowHeight)
            }
        case .intoSection(let id):
            if let index = flatEntries.firstIndex(where: { $0.id == id }) {
                let indent = CGFloat(flatEntries[index].depth) * configuration.indentationWidth
                return CGRect(
                    x: indent,
                    y: CGFloat(index) * configuration.rowHeight,
                    width: bounds.width - indent,
                    height: configuration.rowHeight
                )
            }
        case .rootLevel(let index):
            let y = CGFloat(min(index, flatEntries.count)) * configuration.rowHeight
            return CGRect(x: 0, y: y, width: bounds.width, height: configuration.rowHeight)
        }
        return CGRect(x: 0, y: 0, width: bounds.width, height: configuration.rowHeight)
    }

    // MARK: - Drop Indicator

    func updateDropIndicator(for target: DropTarget<Content>?) {
        guard let target else {
            clearPreviewLayout()
            dropIndicatorLayer.hide()
            return
        }

        guard let payload = dragState.payload else { return }

        let theme = configuration.dropPreviewTheme
        let layout = Arboreal.computePreviewLayout(
            entries: flatEntries,
            target: target,
            payload: payload,
            rowHeight: configuration.rowHeight
        )
        activePreviewLayout = layout

        // Animate cells to their preview positions
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.applyPreviewLayout(layout)
        }

        // Show the preview box in the gap
        let inset = theme.horizontalPadding
        let rect = CGRect(x: inset, y: layout.gapY, width: bounds.width - inset * 2, height: layout.gapHeight)
        dropIndicatorLayer.update(
            for: rect,
            fillColor: UIColor(theme.fillColor),
            borderColor: theme.borderColor.map { UIColor($0) },
            borderWidth: theme.borderWidth,
            cornerRadius: theme.cornerRadius
        )
    }

    private func applyPreviewLayout(_ layout: PreviewLayout<Content>) {
        let rowHeight = configuration.rowHeight

        for (_, entry) in flatEntries.enumerated() {
            let key = AnyHashable(entry.id)
            guard let cell = cellPool.cell(for: key) else { continue }

            if layout.draggedIDs.contains(entry.id) {
                cell.isHidden = true
                continue
            }

            guard let yPosition = layout.entryYPositions[entry.id] else { continue }

            let indent = CGFloat(entry.depth) * configuration.indentationWidth
            cell.transform = .identity
            cell.frame = CGRect(
                x: indent,
                y: yPosition,
                width: bounds.width - indent,
                height: rowHeight
            )
            cell.isHidden = false
            cell.alpha = 1
        }
    }

    private func clearPreviewLayout() {
        guard activePreviewLayout != nil else { return }
        activePreviewLayout = nil

        // Restore all cells to normal positions (including previously hidden dragged cells)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            for (index, entry) in self.flatEntries.enumerated() {
                let key = AnyHashable(entry.id)
                guard let cell = self.cellPool.cell(for: key) else { continue }

                let indent = CGFloat(entry.depth) * self.configuration.indentationWidth
                cell.transform = .identity
                cell.isHidden = false
                cell.alpha = 1
                cell.frame = CGRect(
                    x: indent,
                    y: CGFloat(index) * self.configuration.rowHeight,
                    width: self.bounds.width - indent,
                    height: self.configuration.rowHeight
                )
            }
        }
    }

    // MARK: - Drag State Management

    func transitionDragState(to newState: DragState<Content>) {
        dragState = newState

        switch newState {
        case .idle, .cancelling:
            updateDropIndicator(for: nil)
        case .dragging(_, let target):
            // When target is nil but preview is already active (e.g. just transitioned
            // from .lifting), preserve the current preview layout
            if target == nil, activePreviewLayout != nil {
                break
            }
            updateDropIndicator(for: target)
        case .lifting(let itemID, _):
            updateDropIndicator(for: .before(itemID))
        case .dropping:
            break
        }
    }
}

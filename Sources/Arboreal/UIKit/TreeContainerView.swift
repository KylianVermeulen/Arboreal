import UIKit
import SwiftUI

/// UIScrollView subclass that performs frame-based layout and rendering of tree rows.
///
/// Managed internally by ``TreeDragDropView``. Not intended for direct use.
@MainActor
public final class TreeContainerView<Content: TreeNodeContent>: UIScrollView
where Content: Sendable, Content.ID: Sendable {
    // MARK: - State

    private var flatEntries: [FlatTreeEntry<Content>] = []
    private var rootCount: Int = 0
    private var cellPool = ViewReusePool<TreeNodeCell>(factory: { TreeNodeCell() })
    private var dropIndicatorLayer = DropIndicatorLayer()
    private(set) var dragState: DragState<Content> = .idle
    private var activePreviewLayout: PreviewLayout<Content>?
    private var isAnimatingDropCompletion = false
    #if DEBUG
    private var debugLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        l.numberOfLines = 0
        l.layer.zPosition = 9999
        return l
    }()
    #endif

    // MARK: - Configuration

    var configuration: TreeDragDropConfiguration<Content> = .init()
    var cellContentProvider: (@MainActor (FlatTreeEntry<Content>) -> AnyView)?

    // MARK: - Height Measurement

    private var heightCache: [Content.ID: CGFloat] = [:]
    private var rowHeights: [CGFloat] = []
    private var cumulativeHeights: [CGFloat] = [0]
    private var lastMeasuredWidth: CGFloat = 0
    private let measurementController = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))

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
        #if DEBUG
        addSubview(debugLabel)
        #endif
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

    // MARK: - Height Measurement Helpers

    private func measureHeight(for entry: FlatTreeEntry<Content>) -> CGFloat {
        guard let provider = cellContentProvider else { return 1 }
        let indent = CGFloat(entry.depth) * configuration.indentationWidth
        let availableWidth = bounds.width - indent
        guard availableWidth > 0 else { return 1 }
        measurementController.rootView = provider(entry)
        measurementController.view.frame = CGRect(x: 0, y: 0, width: availableWidth, height: 0)
        let size = measurementController.sizeThatFits(in: CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
        return max(size.height, 1)
    }

    private func measureHeightsIfNeeded() {
        guard bounds.width > 0 else { return }

        // Invalidate entire cache if width changed
        if lastMeasuredWidth != bounds.width {
            heightCache.removeAll()
            lastMeasuredWidth = bounds.width
        }

        var needsRebuild = false
        for entry in flatEntries {
            if heightCache[entry.id] == nil {
                heightCache[entry.id] = measureHeight(for: entry)
                needsRebuild = true
            }
        }

        if needsRebuild || rowHeights.count != flatEntries.count {
            rebuildCumulativeHeights()
        }
    }

    private func rebuildCumulativeHeights() {
        rowHeights = flatEntries.map { heightCache[$0.id]! }
        cumulativeHeights = [0]
        cumulativeHeights.reserveCapacity(flatEntries.count + 1)
        var sum: CGFloat = 0
        for h in rowHeights {
            sum += h
            cumulativeHeights.append(sum)
        }
    }

    private var contentHeight: CGFloat {
        cumulativeHeights.last ?? 0
    }

    private func yPositionForIndex(_ index: Int) -> CGFloat {
        guard index >= 0, index < cumulativeHeights.count else { return 0 }
        return cumulativeHeights[index]
    }

    private func heightForIndex(_ index: Int) -> CGFloat {
        guard index >= 0, index < rowHeights.count else { return 0 }
        return rowHeights[index]
    }

    func heightForEntryID(_ id: Content.ID) -> CGFloat {
        heightCache[id]!
    }

    /// Binary search on cumulativeHeights to find the row index at a given Y position.
    private func indexForYPosition(_ y: CGFloat) -> Int {
        guard !cumulativeHeights.isEmpty else { return 0 }
        var lo = 0
        var hi = cumulativeHeights.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cumulativeHeights[mid + 1] <= y {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return min(lo, flatEntries.count - 1)
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
        rootCount = newEntries.lazy.filter { $0.depth == 0 }.count

        // Use CollectionDifference for efficient updates
        let diff = newEntries.difference(from: oldEntries) { $0.id == $1.id }

        let removedIDs = Set(diff.removals.compactMap { change -> Content.ID? in
            if case .remove(_, let element, _) = change { return element.id }
            return nil
        })

        // Recycle removed cells and invalidate height cache for removed entries
        for id in removedIDs {
            cellPool.recycle(for: AnyHashable(id))
            heightCache.removeValue(forKey: id)
        }

        // Invalidate cache for entries whose content changed
        let oldContentByID = Dictionary(oldEntries.map { ($0.id, $0.content) }, uniquingKeysWith: { _, new in new })
        for entry in newEntries {
            if let oldContent = oldContentByID[entry.id], oldContent != entry.content {
                heightCache.removeValue(forKey: entry.id)
                cellPool.recycle(for: AnyHashable(entry.id))
            }
        }

        // Measure heights and update content size
        measureHeightsIfNeeded()
        contentSize = CGSize(width: bounds.width, height: contentHeight)
        layoutVisibleCells()
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        measureHeightsIfNeeded()
        contentSize = CGSize(width: bounds.width, height: contentHeight)
        layoutVisibleCells()
    }

    private func layoutVisibleCells() {
        // Don't interfere with the drop completion animation
        if isAnimatingDropCompletion { return }

        // During active drag with preview layout, use preview positions
        if let preview = activePreviewLayout, dragState.isDragging {
            layoutVisibleCellsWithPreview(preview)
            return
        }

        // Skip cell recycling during active drag to avoid jitter
        let isDragging = dragState.isDragging

        let visibleMinY = contentOffset.y
        let visibleMaxY = contentOffset.y + bounds.height

        // Binary search for first visible index
        let firstVisible = max(0, indexForYPosition(visibleMinY))
        var lastVisible = firstVisible
        for i in firstVisible..<flatEntries.count {
            if yPositionForIndex(i) > visibleMaxY { break }
            lastVisible = i
        }

        guard firstVisible <= lastVisible, !flatEntries.isEmpty else {
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
                y: yPositionForIndex(index),
                width: bounds.width - indent,
                height: heightForIndex(index)
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
            let entryHeight = heightForEntryID(entry.id)

            if preview.draggedIDs.contains(entry.id) {
                // Children are collapsed via alpha; section is hidden by floating view
                if let cell = cellPool.cell(for: key), entry.depth == 0 {
                    cell.isHidden = true
                }
                continue
            }

            guard let yPosition = preview.entryYPositions[entry.id] else { continue }

            // Check if within visible rect (with buffer)
            let visibleMinY = contentOffset.y - entryHeight
            let visibleMaxY = contentOffset.y + bounds.height + entryHeight
            guard yPosition + entryHeight > visibleMinY,
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
                height: entryHeight
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

    /// Returns the index of the entry at a given Y position. O(log n) via binary search.
    func entryIndex(at point: CGPoint) -> Int? {
        guard !flatEntries.isEmpty, point.y >= 0, point.y < contentHeight else { return nil }
        let index = indexForYPosition(point.y)
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

    func resolveDropTarget(at point: CGPoint, payload: DragPayload<Content>?) -> DropTarget<Content>? {
        let isDraggingRootContent = payload.map { isDraggingRootOnlyContent($0) } ?? false
        let draggedIDs = payload?.draggedIDs ?? []

        // When dragging sections, use whole section groups (header + children)
        // as hit zones: top 50% = before, bottom 50% = after.
        if isDraggingRootContent {
            let target = resolveSectionDropTarget(at: point, draggedIDs: draggedIDs)
            #if DEBUG
            updateDebugLabel(target)
            #endif
            return target
        }

        // During an active drag, use preview positions for hit testing
        // so hidden dragged entries don't intercept touches.
        guard let (entry, rowTop) = findVisibleEntry(at: point, draggedIDs: draggedIDs) else {
            // Point is in the preview gap — keep the current target stable
            if activePreviewLayout != nil, let current = dragState.currentTarget {
                return current
            }
            let raw = DropTarget<Content>.atIndex(parentID: nil, index: rootCount)
            let resolved = redirectRootTarget(raw)
            #if DEBUG
            updateDebugLabel(resolved)
            #endif
            return resolved
        }

        let relativeY = point.y - rowTop
        let fraction = relativeY / heightForEntryID(entry.id)

        // Only depth-0 nodes can be drop-into targets (max depth 1).
        // Never allow dropping into a node that is itself being dragged.
        let allowInto = entry.depth == 0
            && !entry.isExpanded
            && !draggedIDs.contains(entry.id)
            && (entry.hasChildren || entry.content.isContainer)

        let target: DropTarget<Content>

        if allowInto {
            // For collapsed containers: top 30% = before, middle 40% = into, bottom 30% = after
            if fraction < 0.30 {
                target = .atIndex(parentID: entry.parentID, index: entry.indexInParent)
            } else if fraction > 0.70 {
                target = .atIndex(parentID: entry.parentID, index: entry.indexInParent + 1)
            } else {
                target = .intoSection(entry.id)
            }
        } else if entry.isExpanded {
            // For expanded containers: top 50% = before, bottom 50% = first child position
            if fraction < 0.5 {
                target = .atIndex(parentID: entry.parentID, index: entry.indexInParent)
            } else {
                target = .atIndex(parentID: entry.id, index: 0)
            }
        } else {
            // For leaves: top 50% = before, bottom 50% = after
            if fraction < 0.5 {
                target = .atIndex(parentID: entry.parentID, index: entry.indexInParent)
            } else {
                target = .atIndex(parentID: entry.parentID, index: entry.indexInParent + 1)
            }
        }

        let resolved = redirectRootTarget(target)
        #if DEBUG
        updateDebugLabel(resolved)
        #endif
        return resolved
    }

    /// Resolves drop target for section drags using whole section groups as hit zones.
    /// Each group (section header + its visible children) is split 50/50: top half = before, bottom half = after.
    private func resolveSectionDropTarget(at point: CGPoint, draggedIDs: Set<Content.ID>) -> DropTarget<Content> {
        // Build section groups from visible (non-dragged) entries using preview positions
        // Each tuple: (rootEntry, topY, bottomY)
        var groups: [(root: FlatTreeEntry<Content>, topY: CGFloat, bottomY: CGFloat)] = []

        if let preview = activePreviewLayout {
            let visibleRoots = flatEntries.filter { $0.depth == 0 && !preview.draggedIDs.contains($0.id) }
            for root in visibleRoots {
                guard let rootY = preview.entryYPositions[root.id] else { continue }
                var bottomY = rootY + heightForEntryID(root.id)
                for child in flatEntries where child.parentID == root.id && !preview.draggedIDs.contains(child.id) {
                    if let childY = preview.entryYPositions[child.id] {
                        bottomY = max(bottomY, childY + heightForEntryID(child.id))
                    }
                }
                groups.append((root, rootY, bottomY))
            }
        } else {
            for (rootIdx, root) in flatEntries.enumerated() where root.depth == 0 && !draggedIDs.contains(root.id) {
                let topY = yPositionForIndex(rootIdx)
                var endIdx = rootIdx + 1
                while endIdx < flatEntries.count, flatEntries[endIdx].depth > 0 {
                    endIdx += 1
                }
                let bottomY = yPositionForIndex(endIdx)
                groups.append((root, topY, bottomY))
            }
        }

        // Find which section group the point falls in
        for group in groups {
            guard point.y >= group.topY, point.y < group.bottomY else { continue }
            let midY = (group.topY + group.bottomY) / 2
            if point.y < midY {
                return .atIndex(parentID: nil, index: group.root.indexInParent)
            } else {
                return .atIndex(parentID: nil, index: group.root.indexInParent + 1)
            }
        }

        // Point is in the preview gap — keep current target stable
        if activePreviewLayout != nil, let current = dragState.currentTarget {
            return current
        }

        // Below all groups
        return .atIndex(parentID: nil, index: rootCount)
    }

    /// Finds the visible entry at the given point, accounting for preview layout.
    /// Returns the entry and its visual row top Y position, or `nil` if the point
    /// is in the preview gap or outside all entries.
    private func findVisibleEntry(
        at point: CGPoint,
        draggedIDs: Set<Content.ID>
    ) -> (entry: FlatTreeEntry<Content>, rowTop: CGFloat)? {
        if let preview = activePreviewLayout {
            for entry in flatEntries {
                if preview.draggedIDs.contains(entry.id) { continue }
                guard let yPos = preview.entryYPositions[entry.id] else { continue }
                if point.y >= yPos, point.y < yPos + heightForEntryID(entry.id) {
                    return (entry, yPos)
                }
            }
            return nil
        }

        guard let index = entryIndex(at: point) else { return nil }
        let entry = flatEntries[index]
        if draggedIDs.contains(entry.id) { return nil }
        return (entry, yPositionForIndex(index))
    }

    /// Returns true if the payload contains nodes that must stay at root level
    /// (containers or nodes with children).
    private func isDraggingRootOnlyContent(_ payload: DragPayload<Content>) -> Bool {
        let ids = payload.draggedIDs
        return ids.contains { id in
            guard let entry = flatEntries.first(where: { $0.id == id }) else { return false }
            return entry.depth == 0 && (entry.hasChildren || entry.content.isContainer)
        }
    }

    /// Redirects root-level drop targets (except before the first section) into the
    /// previous section. This prevents items from being dropped between sections at
    /// root level; they go into the section above instead.
    private func redirectRootTarget(_ target: DropTarget<Content>) -> DropTarget<Content> {
        guard case .atIndex(parentID: nil, let index) = target, index > 0 else {
            return target
        }

        // Find the previous root entry (the section just above this gap)
        guard let prevRoot = flatEntries.last(where: { $0.depth == 0 && $0.indexInParent < index }) else {
            return target
        }

        if prevRoot.isExpanded {
            // Append after last child — scan forward from prevRoot's position
            guard let prevIdx = flatEntries.lastIndex(where: { $0.id == prevRoot.id }) else {
                return target
            }
            var childCount = 0
            var j = prevIdx + 1
            while j < flatEntries.count, flatEntries[j].depth > 0 {
                childCount += 1
                j += 1
            }
            return .atIndex(parentID: prevRoot.id, index: childCount)
        } else if prevRoot.hasChildren || prevRoot.content.isContainer {
            return .intoSection(prevRoot.id)
        }

        return target
    }

    #if DEBUG
    private func updateDebugLabel(_ target: DropTarget<Content>) {
        switch target {
        case .atIndex(let parentID, let index):
            debugLabel.text = ".atIndex(parentID: \(parentID.map { "\($0)" } ?? "nil"), index: \(index))"
        case .intoSection(let id):
            debugLabel.text = ".intoSection(\(id))"
        }
        debugLabel.sizeToFit()
        debugLabel.frame.origin = CGPoint(x: 8, y: contentOffset.y + bounds.height - debugLabel.frame.height - 8)
    }
    #endif

    // MARK: - Frame Calculations

    func frameForDropTarget(_ target: DropTarget<Content>) -> CGRect {
        switch target {
        case .atIndex(let parentID, let childIndex):
            if let flatIndex = flatIndexForChild(parentID: parentID, childIndex: childIndex) {
                let y = yPositionForIndex(flatIndex)
                let h = heightForIndex(flatIndex)
                return CGRect(x: 0, y: y, width: bounds.width, height: h)
            }
            let y = contentHeight
            return CGRect(x: 0, y: y, width: bounds.width, height: 0)

        case .intoSection(let id):
            if let index = flatEntries.firstIndex(where: { $0.id == id }) {
                let indent = CGFloat(flatEntries[index].depth) * configuration.indentationWidth
                return CGRect(
                    x: indent,
                    y: yPositionForIndex(index),
                    width: bounds.width - indent,
                    height: heightForIndex(index)
                )
            }
            return .zero
        }
    }

    /// Finds the flat-list index of the child at `childIndex` within the parent's children.
    private func flatIndexForChild(parentID: Content.ID?, childIndex: Int) -> Int? {
        let targetDepth: Int
        let searchStart: Int

        if let parentID {
            guard let parentIdx = flatEntries.firstIndex(where: { $0.id == parentID }) else {
                return nil
            }
            targetDepth = flatEntries[parentIdx].depth + 1
            searchStart = parentIdx + 1
        } else {
            targetDepth = 0
            searchStart = 0
        }

        var childCount = 0
        var j = searchStart
        while j < flatEntries.count {
            let entry = flatEntries[j]
            if parentID != nil && entry.depth < targetDepth { break }
            if entry.depth == targetDepth {
                if childCount == childIndex { return j }
                childCount += 1
            }
            j += 1
        }
        // childIndex >= childCount: return position at end of parent's subtree
        return j
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

        if case .intoSection(let sectionID) = target {
            // For drop-into-section: highlight the section header instead of creating a gap.
            // Use a gapless preview layout so dragged cells stay hidden and the gap closes.
            let layout = computeGaplessPreviewLayout(payload: payload)
            activePreviewLayout = layout

            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
                self.applyPreviewLayout(layout)
            }

            if let sectionY = layout.entryYPositions[sectionID] {
                let sectionHeight = heightForEntryID(sectionID)
                let inset = theme.horizontalPadding
                let rect = CGRect(
                    x: inset,
                    y: sectionY,
                    width: bounds.width - inset * 2,
                    height: sectionHeight
                )
                dropIndicatorLayer.update(
                    for: rect,
                    fillColor: UIColor(theme.fillColor),
                    borderColor: theme.borderColor.map { UIColor($0) },
                    borderWidth: theme.borderWidth,
                    cornerRadius: theme.cornerRadius
                )
            }
            return
        }

        let layout = Arboreal.computePreviewLayout(
            entries: flatEntries,
            target: target,
            payload: payload,
            heightForEntry: { self.heightForEntryID($0) }
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
        // Find the Y position of the dragged section for child collapse animation
        var draggedSectionY: CGFloat?
        for (idx, entry) in flatEntries.enumerated() {
            if entry.depth == 0, layout.draggedIDs.contains(entry.id) {
                draggedSectionY = yPositionForIndex(idx)
                break
            }
        }

        for entry in flatEntries {
            let key = AnyHashable(entry.id)
            let entryHeight = heightForEntryID(entry.id)
            guard let cell = cellPool.cell(for: key) else { continue }

            if layout.draggedIDs.contains(entry.id) {
                if entry.depth == 1, let sectionY = draggedSectionY {
                    // Animate children collapsing into the section header
                    cell.transform = .identity
                    cell.isHidden = false
                    cell.frame = CGRect(
                        x: 0,
                        y: sectionY,
                        width: bounds.width,
                        height: entryHeight
                    )
                    cell.alpha = 0
                } else {
                    cell.isHidden = true
                }
                continue
            }

            guard let yPosition = layout.entryYPositions[entry.id] else { continue }

            let indent = CGFloat(entry.depth) * configuration.indentationWidth
            cell.transform = .identity
            cell.frame = CGRect(
                x: indent,
                y: yPosition,
                width: bounds.width - indent,
                height: entryHeight
            )
            cell.isHidden = false
            cell.alpha = 1
        }
    }

    /// Animates from the current preview layout to the new entries' final positions.
    /// Called on drop to smoothly close the gap and slide cells into place.
    /// Dragged entries appear instantly; their children animate expanding from the section header.
    func animateDropCompletion(with newEntries: [FlatTreeEntry<Content>], draggedIDs topLevelDraggedIDs: Set<Content.ID>) {
        flatEntries = newEntries
        activePreviewLayout = nil

        // Measure new entries and rebuild cumulative heights
        measureHeightsIfNeeded()
        contentSize = CGSize(width: bounds.width, height: contentHeight)

        let newIDs = Set(newEntries.map { AnyHashable($0.id) })
        cellPool.recycleAll(except: newIDs)

        let provider = cellContentProvider

        // Expand dragged IDs to include children of dragged sections
        var allDraggedIDs = topLevelDraggedIDs
        for entry in newEntries where entry.depth == 1 {
            if let parentID = entry.parentID, topLevelDraggedIDs.contains(parentID) {
                allDraggedIDs.insert(entry.id)
            }
        }

        // Find the section header Y for each dragged root so children can expand from it
        var draggedSectionY: [Content.ID: CGFloat] = [:]
        for (index, entry) in newEntries.enumerated() where entry.depth == 0 && topLevelDraggedIDs.contains(entry.id) {
            draggedSectionY[entry.id] = yPositionForIndex(index)
        }

        // Kill all in-flight animations so starting positions are clean
        for entry in newEntries {
            let key = AnyHashable(entry.id)
            cellPool.cell(for: key)?.layer.removeAllAnimations()
        }

        // Set starting positions for dragged entries (no animation).
        // Non-dragged entries are already at their preview positions.
        for (index, entry) in newEntries.enumerated() where allDraggedIDs.contains(entry.id) {
            let key = AnyHashable(entry.id)
            let cell = cellPool.dequeue(for: key)

            let indent = CGFloat(entry.depth) * configuration.indentationWidth
            let finalY = yPositionForIndex(index)
            let h = heightForIndex(index)

            cell.transform = .identity
            cell.isHidden = false

            if entry.depth == 0 {
                // Section header: place at final position immediately
                cell.alpha = 1
                cell.frame = CGRect(x: indent, y: finalY, width: bounds.width - indent, height: h)
                bringSubviewToFront(cell)
            } else if let sectionY = entry.parentID.flatMap({ draggedSectionY[$0] }) {
                // Child: start at section header Y with alpha 0, will expand down
                cell.alpha = 0
                cell.frame = CGRect(x: indent, y: sectionY, width: bounds.width - indent, height: h)
            } else {
                cell.alpha = 1
                cell.frame = CGRect(x: indent, y: finalY, width: bounds.width - indent, height: h)
            }

            if cell.superview == nil { addSubview(cell) }
            if let provider { cell.configure(with: provider(entry)) }
        }

        // Prevent layoutVisibleCells from overriding our starting positions
        isAnimatingDropCompletion = true

        // Animate all cells to final positions
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            for (index, entry) in self.flatEntries.enumerated() {
                let key = AnyHashable(entry.id)
                let cell = self.cellPool.dequeue(for: key)
                let indent = CGFloat(entry.depth) * self.configuration.indentationWidth
                let y = self.yPositionForIndex(index)
                let h = self.heightForIndex(index)

                cell.transform = .identity
                cell.isHidden = false
                cell.alpha = 1
                cell.frame = CGRect(x: indent, y: y, width: self.bounds.width - indent, height: h)

                if cell.superview == nil { self.addSubview(cell) }
                if let provider { cell.configure(with: provider(entry)) }
            }
        } completion: { _ in
            self.isAnimatingDropCompletion = false
            self.layoutVisibleCells()
        }

        dropIndicatorLayer.hide()
    }

    private func clearPreviewLayout() {
        guard activePreviewLayout != nil else { return }
        activePreviewLayout = nil

        let activeDraggedIDs = dragState.payload?.draggedIDs ?? []

        // Restore all cells to normal positions (keeping dragged cells hidden)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            for (index, entry) in self.flatEntries.enumerated() {
                let key = AnyHashable(entry.id)
                guard let cell = self.cellPool.cell(for: key) else { continue }

                // Keep dragged cells hidden during active drag
                if activeDraggedIDs.contains(entry.id)
                    || (entry.depth == 1 && entry.parentID.map({ activeDraggedIDs.contains($0) }) == true) {
                    cell.isHidden = true
                    continue
                }

                let indent = CGFloat(entry.depth) * self.configuration.indentationWidth
                cell.transform = .identity
                cell.isHidden = false
                cell.alpha = 1
                cell.frame = CGRect(
                    x: indent,
                    y: self.yPositionForIndex(index),
                    width: self.bounds.width - indent,
                    height: self.heightForIndex(index)
                )
            }
        }
    }

    /// Computes a preview layout that closes the gap left by dragged cells without
    /// inserting any gap at the target. Used for `.intoSection` drop targets.
    private func computeGaplessPreviewLayout(payload: DragPayload<Content>) -> PreviewLayout<Content> {
        let topLevelIDs = payload.draggedIDs
        var draggedIDs = Set<Content.ID>()

        for entry in flatEntries {
            if topLevelIDs.contains(entry.id) {
                draggedIDs.insert(entry.id)
                if entry.depth == 0, entry.isExpanded {
                    for other in flatEntries where other.parentID == entry.id {
                        draggedIDs.insert(other.id)
                    }
                }
            } else if entry.depth == 1, let parentID = entry.parentID, topLevelIDs.contains(parentID) {
                draggedIDs.insert(entry.id)
            }
        }

        var positions: [Content.ID: CGFloat] = [:]
        var runningY: CGFloat = 0
        for entry in flatEntries where !draggedIDs.contains(entry.id) {
            positions[entry.id] = runningY
            runningY += heightForEntryID(entry.id)
        }

        return PreviewLayout(entryYPositions: positions, gapY: 0, gapHeight: 0, draggedIDs: draggedIDs)
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
            if let entry = flatEntries.first(where: { $0.id == itemID }) {
                updateDropIndicator(for: .atIndex(parentID: entry.parentID, index: entry.indexInParent))
            }
        case .dropping:
            break
        }
    }
}

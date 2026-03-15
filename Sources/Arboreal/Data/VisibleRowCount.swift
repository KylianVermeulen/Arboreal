import CoreFoundation

/// Layout information for the preview drop indicator style.
struct PreviewLayout<Content: TreeNodeContent> {
    let entryYPositions: [Content.ID: CGFloat]
    let gapY: CGFloat
    let gapHeight: CGFloat
    let draggedIDs: Set<Content.ID>
}

/// Computes a preview layout: non-dragged entries shift to make room for the
/// dragged items at the target position.
func computePreviewLayout<Content: TreeNodeContent>(
    entries: [FlatTreeEntry<Content>],
    target: DropTarget<Content>,
    payload: DragPayload<Content>,
    heightForEntry: (Content.ID) -> CGFloat,
    nodeSpacing: CGFloat = 0
) -> PreviewLayout<Content> {
    // Collect dragged IDs (including visible children)
    let topLevelIDs = payload.draggedIDs
    var draggedIDs = Set<Content.ID>()

    for entry in entries {
        if topLevelIDs.contains(entry.id) {
            draggedIDs.insert(entry.id)
            if entry.depth == 0, entry.isExpanded {
                for other in entries where other.parentID == entry.id {
                    draggedIDs.insert(other.id)
                }
            }
        } else if entry.depth == 1, let parentID = entry.parentID, topLevelIDs.contains(parentID) {
            draggedIDs.insert(entry.id)
        }
    }

    // Gap height = sum of heights for each top-level dragged item (children are collapsed in the preview)
    var gapHeight: CGFloat = 0
    for id in topLevelIDs {
        gapHeight += heightForEntry(id)
    }

    // Build non-dragged list preserving order
    var nonDragged: [FlatTreeEntry<Content>] = []
    for entry in entries where !draggedIDs.contains(entry.id) {
        nonDragged.append(entry)
    }

    // Find insertion point in the non-dragged list
    let insertionIndex: Int
    switch target {
    case .atIndex(let parentID, let childIndex):
        insertionIndex = resolveInsertionIndex(
            parentID: parentID,
            childIndex: childIndex,
            entries: entries,
            nonDragged: nonDragged,
            draggedIDs: draggedIDs
        )

    case .intoSection(let id):
        if let idx = nonDragged.firstIndex(where: { $0.id == id }) {
            // Section's children are at depth 1; skip past them
            var end = idx + 1
            while end < nonDragged.count, nonDragged[end].depth > nonDragged[idx].depth {
                end += 1
            }
            insertionIndex = end
        } else {
            insertionIndex = nonDragged.count
        }
    }

    // Compute Y positions using actual entry heights
    var positions: [Content.ID: CGFloat] = [:]
    var runningY: CGFloat = 0
    var gapY: CGFloat = 0
    var visualIndex = 0

    for (i, entry) in nonDragged.enumerated() {
        if i == insertionIndex {
            if visualIndex > 0 { runningY += nodeSpacing }
            gapY = runningY
            runningY += gapHeight
            visualIndex += 1
        }
        if visualIndex > 0 { runningY += nodeSpacing }
        positions[entry.id] = runningY
        runningY += heightForEntry(entry.id)
        visualIndex += 1
    }
    // If insertion is at the end
    if insertionIndex >= nonDragged.count {
        if visualIndex > 0 { runningY += nodeSpacing }
        gapY = runningY
    }

    return PreviewLayout(
        entryYPositions: positions,
        gapY: gapY,
        gapHeight: gapHeight,
        draggedIDs: draggedIDs
    )
}

/// Resolves the flat-list insertion index for an `.atIndex` target.
///
/// Uses the anchor-child approach: finds the child at `childIndex` in the original entries,
/// then locates it in the non-dragged list to determine the gap position.
private func resolveInsertionIndex<Content: TreeNodeContent>(
    parentID: Content.ID?,
    childIndex: Int,
    entries: [FlatTreeEntry<Content>],
    nonDragged: [FlatTreeEntry<Content>],
    draggedIDs: Set<Content.ID>
) -> Int {
    // Find direct children of the parent in the original entries
    let targetDepth: Int
    let searchStart: Int

    if let parentID {
        guard let parentIdx = entries.firstIndex(where: { $0.id == parentID }) else {
            return nonDragged.count
        }
        targetDepth = entries[parentIdx].depth + 1
        searchStart = parentIdx + 1
    } else {
        targetDepth = 0
        searchStart = 0
    }

    // Collect direct children at targetDepth
    var directChildren: [FlatTreeEntry<Content>] = []
    for j in searchStart..<entries.count {
        let entry = entries[j]
        if parentID != nil && entry.depth < targetDepth { break }
        if entry.depth == targetDepth {
            directChildren.append(entry)
        }
    }

    // Find anchor: first non-dragged child at or after childIndex
    let anchorID: Content.ID?
    if childIndex < directChildren.count {
        anchorID = directChildren[childIndex...].first(where: { !draggedIDs.contains($0.id) })?.id
    } else {
        anchorID = nil
    }

    if let anchorID, let idx = nonDragged.firstIndex(where: { $0.id == anchorID }) {
        return idx
    }

    // No anchor found — insert at end of parent's subtree in nonDragged
    if let parentID, let parentIdx = nonDragged.firstIndex(where: { $0.id == parentID }) {
        var end = parentIdx + 1
        while end < nonDragged.count, nonDragged[end].depth > nonDragged[parentIdx].depth {
            end += 1
        }
        return end
    }

    return nonDragged.count
}

/// Computes how many visible rows a drag payload occupies in the flattened tree.
func visibleRowCount<Content: TreeNodeContent>(
    for payload: DragPayload<Content>,
    in entries: [FlatTreeEntry<Content>]
) -> Int {
    switch payload {
    case .singleItem(let id), .section(let id):
        return visibleSubtreeCount(for: id, in: entries)

    case .multipleItems(let ids):
        var total = 0
        for id in ids {
            if hasSelectedAncestor(id, in: ids, entries: entries) { continue }
            total += visibleSubtreeCount(for: id, in: entries)
        }
        return max(total, 1)
    }
}

private func visibleSubtreeCount<Content: TreeNodeContent>(
    for id: Content.ID,
    in entries: [FlatTreeEntry<Content>]
) -> Int {
    guard let entry = entries.first(where: { $0.id == id }) else {
        return 1
    }
    // Depth-0 expanded nodes: count self + visible children
    if entry.depth == 0, entry.isExpanded {
        return 1 + entries.filter { $0.parentID == id }.count
    }
    // Depth-1 nodes or collapsed depth-0 nodes: just 1
    return 1
}

private func hasSelectedAncestor<Content: TreeNodeContent>(
    _ id: Content.ID,
    in ids: Set<Content.ID>,
    entries: [FlatTreeEntry<Content>]
) -> Bool {
    guard let entry = entries.first(where: { $0.id == id }) else { return false }
    // With max depth 1, the only possible ancestor is the parent
    guard let parentID = entry.parentID else { return false }
    return ids.contains(parentID)
}

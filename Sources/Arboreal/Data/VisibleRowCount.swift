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
    rowHeight: CGFloat
) -> PreviewLayout<Content> {
    // Collect dragged IDs (including visible descendants)
    let topLevelIDs = draggedIDSet(from: payload)
    var draggedIDs = Set<Content.ID>()
    var draggedRowCount = 0

    var i = 0
    while i < entries.count {
        let entry = entries[i]
        if topLevelIDs.contains(entry.id) {
            draggedIDs.insert(entry.id)
            draggedRowCount += 1
            let baseDepth = entry.depth
            i += 1
            while i < entries.count, entries[i].depth > baseDepth {
                draggedIDs.insert(entries[i].id)
                draggedRowCount += 1
                i += 1
            }
        } else {
            i += 1
        }
    }

    // Build non-dragged list preserving order
    var nonDragged: [FlatTreeEntry<Content>] = []
    for entry in entries where !draggedIDs.contains(entry.id) {
        nonDragged.append(entry)
    }

    // Find insertion point in the non-dragged list
    let insertionIndex: Int
    switch target {
    case .before(let id):
        if let idx = nonDragged.firstIndex(where: { $0.id == id }) {
            insertionIndex = idx
        } else if draggedIDs.contains(id),
                  let originalIdx = entries.firstIndex(where: { $0.id == id }) {
            // The target is itself being dragged — find the first non-dragged
            // entry at or after the original position.
            let afterOriginal = nonDragged.firstIndex(where: { entry in
                guard let entryIdx = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
                return entryIdx >= originalIdx
            })
            insertionIndex = afterOriginal ?? nonDragged.count
        } else {
            insertionIndex = nonDragged.count
        }

    case .after(let id):
        if let idx = nonDragged.firstIndex(where: { $0.id == id }) {
            // Skip past this entry's visible subtree
            let baseDepth = nonDragged[idx].depth
            var end = idx + 1
            while end < nonDragged.count, nonDragged[end].depth > baseDepth {
                end += 1
            }
            insertionIndex = end
        } else if draggedIDs.contains(id),
                  let originalIdx = entries.firstIndex(where: { $0.id == id }) {
            // The target is itself being dragged — find insertion after its
            // subtree in the original list, then map to non-dragged index.
            let baseDepth = entries[originalIdx].depth
            var end = originalIdx + 1
            while end < entries.count, entries[end].depth > baseDepth {
                end += 1
            }
            let afterOriginal = nonDragged.firstIndex(where: { entry in
                guard let entryIdx = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
                return entryIdx >= end
            })
            insertionIndex = afterOriginal ?? nonDragged.count
        } else {
            insertionIndex = nonDragged.count
        }

    case .intoSection(let id):
        if let idx = nonDragged.firstIndex(where: { $0.id == id }) {
            let sectionDepth = nonDragged[idx].depth
            var end = idx + 1
            while end < nonDragged.count, nonDragged[end].depth > sectionDepth {
                end += 1
            }
            insertionIndex = end
        } else {
            insertionIndex = nonDragged.count
        }

    case .rootLevel(let index):
        var rootCount = 0
        var mapped = nonDragged.count
        for (i, item) in nonDragged.enumerated() {
            if item.depth == 0 {
                if rootCount == index {
                    mapped = i
                    break
                }
                rootCount += 1
            }
        }
        insertionIndex = mapped
    }

    let gapHeight = CGFloat(draggedRowCount) * rowHeight
    let gapY = CGFloat(insertionIndex) * rowHeight

    var positions: [Content.ID: CGFloat] = [:]
    for (i, entry) in nonDragged.enumerated() {
        if i < insertionIndex {
            positions[entry.id] = CGFloat(i) * rowHeight
        } else {
            positions[entry.id] = CGFloat(i) * rowHeight + gapHeight
        }
    }

    return PreviewLayout(
        entryYPositions: positions,
        gapY: gapY,
        gapHeight: gapHeight,
        draggedIDs: draggedIDs
    )
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

private func draggedIDSet<Content: TreeNodeContent>(from payload: DragPayload<Content>) -> Set<Content.ID> {
    switch payload {
    case .singleItem(let id), .section(let id): [id]
    case .multipleItems(let ids): ids
    }
}

private func visibleSubtreeCount<Content: TreeNodeContent>(
    for id: Content.ID,
    in entries: [FlatTreeEntry<Content>]
) -> Int {
    guard let startIndex = entries.firstIndex(where: { $0.id == id }) else {
        return 1
    }
    let baseDepth = entries[startIndex].depth
    var count = 1
    var i = startIndex + 1
    while i < entries.count, entries[i].depth > baseDepth {
        count += 1
        i += 1
    }
    return count
}

private func hasSelectedAncestor<Content: TreeNodeContent>(
    _ id: Content.ID,
    in ids: Set<Content.ID>,
    entries: [FlatTreeEntry<Content>]
) -> Bool {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
    let depth = entries[index].depth
    var i = index - 1
    while i >= 0 {
        let entry = entries[i]
        if entry.depth < depth, ids.contains(entry.id) {
            return true
        }
        if entry.depth == 0 { break }
        i -= 1
    }
    return false
}

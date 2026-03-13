/// Extracts nodes with the given IDs from the tree, returning the modified tree and extracted nodes.
public func extractNodes<Content: TreeNodeContent>(
    from roots: [TreeNode<Content>],
    ids: Set<Content.ID>
) -> (remaining: [TreeNode<Content>], extracted: [TreeNode<Content>]) {
    var extracted: [TreeNode<Content>] = []
    var remaining: [TreeNode<Content>] = []

    for var root in roots {
        if ids.contains(root.id) {
            extracted.append(root)
        } else {
            root.children = root.children.filter { child in
                if ids.contains(child.id) {
                    extracted.append(child)
                    return false
                }
                return true
            }
            remaining.append(root)
        }
    }

    return (remaining, extracted)
}

/// Inserts nodes at the specified drop target location.
public func insertNodes<Content: TreeNodeContent>(
    into roots: [TreeNode<Content>],
    nodes: [TreeNode<Content>],
    at target: DropTarget<Content>
) -> [TreeNode<Content>] {
    switch target {
    case .atIndex(let parentID, let index):
        if let parentID {
            return insertAtIndex(roots: roots, nodes: nodes, parentID: parentID, index: index)
        } else {
            var result = roots
            let clamped = min(max(index, 0), result.count)
            result.insert(contentsOf: nodes, at: clamped)
            return result
        }

    case .intoSection(let parentID):
        return insertAtIndex(roots: roots, nodes: nodes, parentID: parentID, index: Int.max)
    }
}

private func insertAtIndex<Content: TreeNodeContent>(
    roots: [TreeNode<Content>],
    nodes: [TreeNode<Content>],
    parentID: Content.ID,
    index: Int
) -> [TreeNode<Content>] {
    roots.map { node in
        var node = node
        if node.id == parentID {
            let clamped = min(max(index, 0), node.children.count)
            node.children.insert(contentsOf: nodes, at: clamped)
        }
        return node
    }
}

/// Performs a complete move operation: extract then insert.
/// Handles index adjustment when dragged nodes shift child indices.
public func moveNodes<Content: TreeNodeContent>(
    in roots: [TreeNode<Content>],
    ids: Set<Content.ID>,
    to target: DropTarget<Content>
) -> [TreeNode<Content>] {
    switch target {
    case .atIndex(let parentID, let index):
        // Find the anchor child (first non-dragged child at or after `index`)
        // so we can locate the correct insertion point after extraction.
        let currentSiblings = siblings(ofParent: parentID, in: roots)

        let anchorID: Content.ID?
        if index < currentSiblings.count {
            anchorID = currentSiblings[index...].first(where: { !ids.contains($0.id) })?.id
        } else {
            anchorID = nil
        }

        let (remaining, extracted) = extractNodes(from: roots, ids: ids)
        guard !extracted.isEmpty else { return roots }

        // Recompute index in the remaining tree
        let remainingSiblings = siblings(ofParent: parentID, in: remaining)

        let adjustedIndex: Int
        if let anchorID, let anchorIdx = remainingSiblings.firstIndex(where: { $0.id == anchorID }) {
            adjustedIndex = anchorIdx
        } else {
            adjustedIndex = remainingSiblings.count
        }

        return insertNodes(into: remaining, nodes: extracted, at: .atIndex(parentID: parentID, index: adjustedIndex))

    case .intoSection:
        let (remaining, extracted) = extractNodes(from: roots, ids: ids)
        guard !extracted.isEmpty else { return roots }
        return insertNodes(into: remaining, nodes: extracted, at: target)
    }
}

/// Checks if a drop would create a cycle (dropping a parent into its own descendant).
public func canDrop<Content: TreeNodeContent>(
    in roots: [TreeNode<Content>],
    draggedIDs: Set<Content.ID>,
    onto target: DropTarget<Content>
) -> Bool {
    let targetParentID: Content.ID?
    switch target {
    case .atIndex(let parentID, _):
        targetParentID = parentID
    case .intoSection(let id):
        if draggedIDs.contains(id) { return false }
        targetParentID = id
    }

    guard let targetParentID else { return true }
    if draggedIDs.contains(targetParentID) { return false }

    // With max depth 1, dropping into a parent places nodes at depth 1.
    // Nodes with children or containers cannot exist at depth 1.
    for draggedID in draggedIDs {
        if let node = findNode(id: draggedID, in: roots) {
            if !node.children.isEmpty || node.content.isContainer {
                return false
            }
        }
    }

    return true
}

/// Check if `possibleDescendant` is a descendant of the node with `ancestorID`.
func isDescendant<Content: TreeNodeContent>(
    _ possibleDescendant: Content.ID,
    of ancestorID: Content.ID,
    in roots: [TreeNode<Content>]
) -> Bool {
    guard let ancestor = findNode(id: ancestorID, in: roots) else { return false }
    return ancestor.children.contains(where: { $0.id == possibleDescendant })
}

/// Returns the children of the node with `parentID`, or `roots` if `parentID` is nil.
func siblings<Content: TreeNodeContent>(
    ofParent parentID: Content.ID?,
    in roots: [TreeNode<Content>]
) -> [TreeNode<Content>] {
    if let parentID {
        return findNode(id: parentID, in: roots)?.children ?? []
    }
    return roots
}

func findNode<Content: TreeNodeContent>(
    id: Content.ID,
    in nodes: [TreeNode<Content>]
) -> TreeNode<Content>? {
    for node in nodes {
        if node.id == id { return node }
        for child in node.children {
            if child.id == id { return child }
        }
    }
    return nil
}

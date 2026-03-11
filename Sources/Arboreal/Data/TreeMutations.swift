/// Extracts nodes with the given IDs from the tree, returning the modified tree and extracted nodes.
public func extractNodes<Content: TreeNodeContent>(
    from roots: [TreeNode<Content>],
    ids: Set<Content.ID>
) -> (remaining: [TreeNode<Content>], extracted: [TreeNode<Content>]) {
    var extracted: [TreeNode<Content>] = []

    func filter(_ nodes: [TreeNode<Content>]) -> [TreeNode<Content>] {
        var result: [TreeNode<Content>] = []
        for var node in nodes {
            if ids.contains(node.id) {
                extracted.append(node)
            } else {
                node.children = filter(node.children)
                result.append(node)
            }
        }
        return result
    }

    let remaining = filter(roots)
    return (remaining, extracted)
}

/// Inserts nodes at the specified drop target location.
public func insertNodes<Content: TreeNodeContent>(
    into roots: [TreeNode<Content>],
    nodes: [TreeNode<Content>],
    at target: DropTarget<Content>
) -> [TreeNode<Content>] {
    switch target {
    case .rootLevel(let index):
        var result = roots
        let clampedIndex = min(max(index, 0), result.count)
        result.insert(contentsOf: nodes, at: clampedIndex)
        return result

    case .before(let targetID):
        return insertRelative(into: roots, nodes: nodes, targetID: targetID, position: .before)

    case .after(let targetID):
        return insertRelative(into: roots, nodes: nodes, targetID: targetID, position: .after)

    case .intoSection(let parentID):
        return insertIntoContainer(roots: roots, nodes: nodes, parentID: parentID)
    }
}

private enum RelativePosition {
    case before, after
}

private func insertRelative<Content: TreeNodeContent>(
    into nodes: [TreeNode<Content>],
    nodes toInsert: [TreeNode<Content>],
    targetID: Content.ID,
    position: RelativePosition
) -> [TreeNode<Content>] {
    var result: [TreeNode<Content>] = []
    for var node in nodes {
        if node.id == targetID {
            switch position {
            case .before:
                result.append(contentsOf: toInsert)
                result.append(node)
            case .after:
                result.append(node)
                result.append(contentsOf: toInsert)
            }
        } else {
            node.children = insertRelative(into: node.children, nodes: toInsert, targetID: targetID, position: position)
            result.append(node)
        }
    }
    return result
}

private func insertIntoContainer<Content: TreeNodeContent>(
    roots: [TreeNode<Content>],
    nodes: [TreeNode<Content>],
    parentID: Content.ID
) -> [TreeNode<Content>] {
    roots.map { node in
        var node = node
        if node.id == parentID {
            node.children.append(contentsOf: nodes)
        } else {
            node.children = insertIntoContainer(roots: node.children, nodes: nodes, parentID: parentID)
        }
        return node
    }
}

/// Performs a complete move operation: extract then insert.
public func moveNodes<Content: TreeNodeContent>(
    in roots: [TreeNode<Content>],
    ids: Set<Content.ID>,
    to target: DropTarget<Content>
) -> [TreeNode<Content>] {
    let (remaining, extracted) = extractNodes(from: roots, ids: ids)
    guard !extracted.isEmpty else { return roots }
    return insertNodes(into: remaining, nodes: extracted, at: target)
}

/// Checks if a drop would create a cycle (dropping a parent into its own descendant).
public func canDrop<Content: TreeNodeContent>(
    in roots: [TreeNode<Content>],
    draggedIDs: Set<Content.ID>,
    onto target: DropTarget<Content>
) -> Bool {
    // Reject dropping before/after/into the dragged item itself
    switch target {
    case .before(let id), .after(let id), .intoSection(let id):
        if draggedIDs.contains(id) { return false }
    case .rootLevel:
        break
    }

    // Get the target parent ID
    let targetParentID: Content.ID?
    switch target {
    case .rootLevel:
        return true // Can always drop at root level
    case .intoSection(let parentID):
        targetParentID = parentID
    case .before(let siblingID), .after(let siblingID):
        targetParentID = findParentID(in: roots, of: siblingID)
    }

    guard let targetParentID else { return true }

    // If dropping into one of the dragged items, that's not allowed
    if draggedIDs.contains(targetParentID) { return false }

    // Check if the target parent is a descendant of any dragged node
    for draggedID in draggedIDs {
        if isDescendant(targetParentID, of: draggedID, in: roots) {
            return false
        }
    }

    return true
}

/// Find the parent ID of a node with the given ID.
private func findParentID<Content: TreeNodeContent>(
    in roots: [TreeNode<Content>],
    of targetID: Content.ID
) -> Content.ID? {
    for root in roots {
        if let result = findParentID(in: root, of: targetID) {
            return result
        }
    }
    return nil
}

private func findParentID<Content: TreeNodeContent>(
    in node: TreeNode<Content>,
    of targetID: Content.ID
) -> Content.ID? {
    for child in node.children {
        if child.id == targetID {
            return node.id
        }
        if let found = findParentID(in: child, of: targetID) {
            return found
        }
    }
    return nil
}

/// Check if `possibleDescendant` is a descendant of the node with `ancestorID`.
private func isDescendant<Content: TreeNodeContent>(
    _ possibleDescendant: Content.ID,
    of ancestorID: Content.ID,
    in roots: [TreeNode<Content>]
) -> Bool {
    guard let ancestor = findNode(id: ancestorID, in: roots) else { return false }
    return containsNode(id: possibleDescendant, in: ancestor.children)
}

private func findNode<Content: TreeNodeContent>(
    id: Content.ID,
    in nodes: [TreeNode<Content>]
) -> TreeNode<Content>? {
    for node in nodes {
        if node.id == id { return node }
        if let found = findNode(id: id, in: node.children) { return found }
    }
    return nil
}

private func containsNode<Content: TreeNodeContent>(
    id: Content.ID,
    in nodes: [TreeNode<Content>]
) -> Bool {
    for node in nodes {
        if node.id == id { return true }
        if containsNode(id: id, in: node.children) { return true }
    }
    return false
}

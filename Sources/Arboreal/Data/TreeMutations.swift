extension Array {
    /// Extracts nodes with the given IDs from the tree, returning the modified tree and extracted nodes.
    public func extractingNodes<Content: TreeNodeContent>(
        ids: Set<Content.ID>
    ) -> (remaining: [TreeNode<Content>], extracted: [TreeNode<Content>]) where Element == TreeNode<Content> {
        var extracted: [TreeNode<Content>] = []
        var remaining: [TreeNode<Content>] = []

        for var root in self {
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
    public func insertingNodes<Content: TreeNodeContent>(
        _ nodes: [TreeNode<Content>],
        at target: DropTarget<Content>
    ) -> [TreeNode<Content>] where Element == TreeNode<Content> {
        switch target {
        case .atIndex(let parentID, let index):
            if let parentID {
                return insertingAtIndex(nodes, parentID: parentID, index: index)
            } else {
                var result = self
                let clamped = Swift.min(Swift.max(index, 0), result.count)
                result.insert(contentsOf: nodes, at: clamped)
                return result
            }

        case .intoSection(let parentID):
            return insertingAtIndex(nodes, parentID: parentID, index: Int.max)
        }
    }

    /// Performs a complete move operation: extract then insert.
    /// Handles index adjustment when dragged nodes shift child indices.
    public func movingNodes<Content: TreeNodeContent>(
        ids: Set<Content.ID>,
        to target: DropTarget<Content>
    ) -> [TreeNode<Content>] where Element == TreeNode<Content> {
        switch target {
        case .atIndex(let parentID, let index):
            // Find the anchor child (first non-dragged child at or after `index`)
            // so we can locate the correct insertion point after extraction.
            let currentSiblings = siblings(ofParent: parentID)

            let anchorID: Content.ID?
            if index < currentSiblings.count {
                anchorID = currentSiblings[index...].first(where: { !ids.contains($0.id) })?.id
            } else {
                anchorID = nil
            }

            let (remaining, extracted) = extractingNodes(ids: ids)
            guard !extracted.isEmpty else { return self }

            // Recompute index in the remaining tree
            let remainingSiblings = remaining.siblings(ofParent: parentID)

            let adjustedIndex: Int
            if let anchorID, let anchorIdx = remainingSiblings.firstIndex(where: { $0.id == anchorID }) {
                adjustedIndex = anchorIdx
            } else {
                adjustedIndex = remainingSiblings.count
            }

            return remaining.insertingNodes(extracted, at: .atIndex(parentID: parentID, index: adjustedIndex))

        case .intoSection:
            let (remaining, extracted) = extractingNodes(ids: ids)
            guard !extracted.isEmpty else { return self }
            return remaining.insertingNodes(extracted, at: target)
        }
    }

    /// Checks if a drop would create a cycle (dropping a parent into its own descendant).
    public func canDrop<Content: TreeNodeContent>(
        draggedIDs: Set<Content.ID>,
        onto target: DropTarget<Content>
    ) -> Bool where Element == TreeNode<Content> {
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
            if let node = findNode(id: draggedID) {
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
        of ancestorID: Content.ID
    ) -> Bool where Element == TreeNode<Content> {
        guard let ancestor = findNode(id: ancestorID) else { return false }
        return ancestor.children.contains(where: { $0.id == possibleDescendant })
    }

    /// Returns the children of the node with `parentID`, or `self` if `parentID` is nil.
    func siblings<Content: TreeNodeContent>(
        ofParent parentID: Content.ID?
    ) -> [TreeNode<Content>] where Element == TreeNode<Content> {
        if let parentID {
            return findNode(id: parentID)?.children ?? []
        }
        return self
    }

    func findNode<Content: TreeNodeContent>(
        id: Content.ID
    ) -> TreeNode<Content>? where Element == TreeNode<Content> {
        for node in self {
            if node.id == id { return node }
            for child in node.children {
                if child.id == id { return child }
            }
        }
        return nil
    }

    private func insertingAtIndex<Content: TreeNodeContent>(
        _ nodes: [TreeNode<Content>],
        parentID: Content.ID,
        index: Int
    ) -> [TreeNode<Content>] where Element == TreeNode<Content> {
        map { node in
            var node = node
            if node.id == parentID {
                let clamped = Swift.min(Swift.max(index, 0), node.children.count)
                node.children.insert(contentsOf: nodes, at: clamped)
            }
            return node
        }
    }
}

extension Array {
    /// Converts a tree of nodes into a flat array of entries suitable for layout.
    ///
    /// Expanded nodes have their children included inline. Collapsed nodes are represented
    /// as a single entry. Runs in O(n) time where n is the number of visible nodes.
    ///
    /// - Parameter expansionState: The set of node IDs whose children should be visible.
    /// - Returns: A flat array of ``FlatTreeEntry`` values ordered for display.
    public func flattened<Content: TreeNodeContent>(
        expansionState: Set<Content.ID>
    ) -> [FlatTreeEntry<Content>] where Element == TreeNode<Content> {
        var result: [FlatTreeEntry<Content>] = []
        let rootCount = count

        for (rootIndex, root) in enumerated() {
            let isExpanded = expansionState.contains(root.id)
            let hasChildren = !root.children.isEmpty

            result.append(FlatTreeEntry(
                id: root.id,
                content: root.content,
                depth: 0,
                parentID: nil,
                indexInParent: rootIndex,
                hasChildren: hasChildren,
                isExpanded: isExpanded && hasChildren,
                isLastChild: rootIndex == rootCount - 1
            ))

            if isExpanded && hasChildren {
                let childCount = root.children.count
                for (childIndex, child) in root.children.enumerated() {
                    result.append(FlatTreeEntry(
                        id: child.id,
                        content: child.content,
                        depth: 1,
                        parentID: root.id,
                        indexInParent: childIndex,
                        hasChildren: false,
                        isExpanded: false,
                        isLastChild: childIndex == childCount - 1
                    ))
                }
            }
        }

        return result
    }
}

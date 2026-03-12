public func flattenTree<Content: TreeNodeContent>(
    _ roots: [TreeNode<Content>],
    expansionState: @autoclosure () -> Set<Content.ID>
) -> [FlatTreeEntry<Content>] {
    let expanded = expansionState()
    var result: [FlatTreeEntry<Content>] = []
    let rootCount = roots.count

    for (rootIndex, root) in roots.enumerated() {
        let isExpanded = expanded.contains(root.id)
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

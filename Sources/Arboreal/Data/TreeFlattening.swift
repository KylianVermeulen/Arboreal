public func flattenTree<Content: TreeNodeContent>(
    _ roots: [TreeNode<Content>],
    expansionState: @autoclosure () -> Set<Content.ID>
) -> [FlatTreeEntry<Content>] {
    let expanded = expansionState()
    var result: [FlatTreeEntry<Content>] = []

    // Stack entries: (node, depth, parentID, indexInParent, siblingCount)
    var stack: [(node: TreeNode<Content>, depth: Int, parentID: Content.ID?, indexInParent: Int, siblingCount: Int)] = []

    // Push roots in reverse order so first root is processed first
    let rootCount = roots.count
    for (index, root) in roots.enumerated().reversed() {
        stack.append((root, 0, nil, index, rootCount))
    }

    while let (node, depth, parentID, indexInParent, siblingCount) = stack.popLast() {
        let isExpanded = expanded.contains(node.id)
        let hasChildren = !node.children.isEmpty

        result.append(FlatTreeEntry(
            id: node.id,
            content: node.content,
            depth: depth,
            parentID: parentID,
            indexInParent: indexInParent,
            hasChildren: hasChildren,
            isExpanded: isExpanded && hasChildren,
            isLastChild: indexInParent == siblingCount - 1
        ))

        if isExpanded && hasChildren {
            let childCount = node.children.count
            for (index, child) in node.children.enumerated().reversed() {
                stack.append((child, depth + 1, node.id, index, childCount))
            }
        }
    }

    return result
}

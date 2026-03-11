public func flattenTree<Content: TreeNodeContent>(
    _ roots: [TreeNode<Content>],
    expansionState: @autoclosure () -> Set<Content.ID>
) -> [FlatTreeEntry<Content>] {
    let expanded = expansionState()
    var result: [FlatTreeEntry<Content>] = []

    // Stack entries: (node, depth, parentID, indexInParent)
    var stack: [(node: TreeNode<Content>, depth: Int, parentID: Content.ID?, indexInParent: Int)] = []

    // Push roots in reverse order so first root is processed first
    for (index, root) in roots.enumerated().reversed() {
        stack.append((root, 0, nil, index))
    }

    while let (node, depth, parentID, indexInParent) = stack.popLast() {
        let isExpanded = expanded.contains(node.id)
        let hasChildren = !node.children.isEmpty

        result.append(FlatTreeEntry(
            id: node.id,
            content: node.content,
            depth: depth,
            parentID: parentID,
            indexInParent: indexInParent,
            hasChildren: hasChildren,
            isExpanded: isExpanded && hasChildren
        ))

        if isExpanded && hasChildren {
            for (index, child) in node.children.enumerated().reversed() {
                stack.append((child, depth + 1, node.id, index))
            }
        }
    }

    return result
}

import Arboreal

struct TestContent: TreeNodeContent {
    var id: String
    var isContainer: Bool

    init(_ id: String, isContainer: Bool = false) {
        self.id = id
        self.isContainer = isContainer
    }
}

/// Helper to build trees for testing.
func node(_ id: String, isContainer: Bool = false, children: [TreeNode<TestContent>] = []) -> TreeNode<TestContent> {
    TreeNode(content: TestContent(id, isContainer: isContainer), children: children)
}

import Testing
@testable import Arboreal

@Suite("TreeNode Tests")
struct TreeNodeTests {
    @Test("TreeNode identity is based on ID")
    func identity() {
        let a = node("A")
        let b = node("A") // same ID
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("TreeNode with different IDs are not equal")
    func differentIDs() {
        let a = node("A")
        let b = node("B")
        #expect(a != b)
    }

    @Test("TreeNode children are accessible")
    func children() {
        let tree = node("root", children: [node("child1"), node("child2")])
        #expect(tree.children.count == 2)
        #expect(tree.children[0].id == "child1")
        #expect(tree.children[1].id == "child2")
    }
}

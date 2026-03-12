import Testing
@testable import Arboreal

@Suite("Tree Flattening Tests")
struct TreeFlatteningTests {
    @Test("Empty tree produces empty result")
    func emptyTree() {
        let result = flattenTree([TreeNode<TestContent>](), expansionState: Set<String>())
        #expect(result.isEmpty)
    }

    @Test("Single root node")
    func singleRoot() {
        let tree = [node("root")]
        let result = flattenTree(tree, expansionState: Set<String>())
        #expect(result.count == 1)
        #expect(result[0].id == "root")
        #expect(result[0].depth == 0)
        #expect(result[0].parentID == nil)
        #expect(result[0].indexInParent == 0)
        #expect(result[0].isLastChild == true)
    }

    @Test("Collapsed parent hides children")
    func collapsedParent() {
        let tree = [node("root", children: [node("child1"), node("child2")])]
        let result = flattenTree(tree, expansionState: Set<String>()) // nothing expanded
        #expect(result.count == 1)
        #expect(result[0].id == "root")
        #expect(result[0].hasChildren == true)
        #expect(result[0].isExpanded == false)
    }

    @Test("Expanded parent shows children")
    func expandedParent() {
        let tree = [node("root", children: [node("child1"), node("child2")])]
        let result = flattenTree(tree, expansionState: Set(["root"]))
        #expect(result.count == 3)
        #expect(result[0].id == "root")
        #expect(result[0].isExpanded == true)
        #expect(result[1].id == "child1")
        #expect(result[1].depth == 1)
        #expect(result[1].parentID == "root")
        #expect(result[1].indexInParent == 0)
        #expect(result[2].id == "child2")
        #expect(result[2].indexInParent == 1)
    }

    @Test("Children are always at depth 1")
    func childrenAtDepthOne() {
        let tree = [node("A", children: [node("B"), node("C")])]
        let result = flattenTree(tree, expansionState: Set(["A"]))
        #expect(result.count == 3)
        #expect(result[0].depth == 0)
        #expect(result[1].depth == 1)
        #expect(result[1].hasChildren == false)
        #expect(result[2].depth == 1)
        #expect(result[2].parentID == "A")
    }

    @Test("Multiple roots preserve order")
    func multipleRoots() {
        let tree = [node("A"), node("B"), node("C")]
        let result = flattenTree(tree, expansionState: Set<String>())
        #expect(result.count == 3)
        #expect(result[0].id == "A")
        #expect(result[0].indexInParent == 0)
        #expect(result[0].isLastChild == false)
        #expect(result[1].id == "B")
        #expect(result[1].indexInParent == 1)
        #expect(result[1].isLastChild == false)
        #expect(result[2].id == "C")
        #expect(result[2].indexInParent == 2)
        #expect(result[2].isLastChild == true)
    }

    @Test("Leaf node marked as not having children")
    func leafNode() {
        let tree = [node("leaf")]
        let result = flattenTree(tree, expansionState: Set(["leaf"])) // expanding leaf does nothing
        #expect(result.count == 1)
        #expect(result[0].hasChildren == false)
        #expect(result[0].isExpanded == false) // no children so not expanded
    }
}

import Testing
@testable import Arboreal

@Suite("Tree Mutation Tests")
struct TreeMutationTests {
    // MARK: - Extract

    @Test("Extract single node from roots")
    func extractFromRoots() {
        let tree = [node("A"), node("B"), node("C")]
        let (remaining, extracted) = tree.extractingNodes(ids: Set(["B"]))
        #expect(remaining.count == 2)
        #expect(remaining[0].id == "A")
        #expect(remaining[1].id == "C")
        #expect(extracted.count == 1)
        #expect(extracted[0].id == "B")
    }

    @Test("Extract nested node")
    func extractNested() {
        let tree = [node("root", children: [node("child1"), node("child2")])]
        let (remaining, extracted) = tree.extractingNodes(ids: Set(["child1"]))
        #expect(remaining.count == 1)
        #expect(remaining[0].children.count == 1)
        #expect(remaining[0].children[0].id == "child2")
        #expect(extracted.count == 1)
        #expect(extracted[0].id == "child1")
    }

    // MARK: - Insert

    @Test("Insert at root level")
    func insertAtRoot() {
        let tree = [node("A"), node("C")]
        let result = tree.insertingNodes([node("B")], at: .atIndex(parentID: nil, index: 1))
        #expect(result.count == 3)
        #expect(result[0].id == "A")
        #expect(result[1].id == "B")
        #expect(result[2].id == "C")
    }

    @Test("Insert before node")
    func insertBefore() {
        let tree = [node("A"), node("C")]
        let result = tree.insertingNodes([node("B")], at: .atIndex(parentID: nil, index: 1))
        #expect(result.count == 3)
        #expect(result[1].id == "B")
        #expect(result[2].id == "C")
    }

    @Test("Insert after node")
    func insertAfter() {
        let tree = [node("A"), node("C")]
        let result = tree.insertingNodes([node("B")], at: .atIndex(parentID: nil, index: 1))
        #expect(result.count == 3)
        #expect(result[0].id == "A")
        #expect(result[1].id == "B")
    }

    @Test("Insert into container")
    func insertInto() {
        let tree = [node("parent", isContainer: true)]
        let result = tree.insertingNodes([node("child")], at: .intoSection("parent"))
        #expect(result[0].children.count == 1)
        #expect(result[0].children[0].id == "child")
    }

    @Test("Insert at index within parent")
    func insertAtIndexInParent() {
        let tree = [node("parent", children: [node("A"), node("C")])]
        let result = tree.insertingNodes([node("B")], at: .atIndex(parentID: "parent", index: 1))
        #expect(result[0].children.count == 3)
        #expect(result[0].children[0].id == "A")
        #expect(result[0].children[1].id == "B")
        #expect(result[0].children[2].id == "C")
    }

    @Test("Insert at end of parent children")
    func insertAtEndOfParent() {
        let tree = [node("parent", children: [node("A")])]
        let result = tree.insertingNodes([node("B")], at: .atIndex(parentID: "parent", index: 1))
        #expect(result[0].children.count == 2)
        #expect(result[0].children[1].id == "B")
    }

    // MARK: - Move

    @Test("Move node between siblings")
    func moveBetweenSiblings() {
        let tree = [node("A"), node("B"), node("C")]
        let result = tree.movingNodes(ids: Set(["C"]), to: .atIndex(parentID: nil, index: 0))
        #expect(result.count == 3)
        #expect(result[0].id == "C")
        #expect(result[1].id == "A")
        #expect(result[2].id == "B")
    }

    @Test("Move node forward adjusts index correctly")
    func moveForward() {
        // Move A to after B (index 2 in original, but A is extracted so index shifts)
        let tree = [node("A"), node("B"), node("C")]
        let result = tree.movingNodes(ids: Set(["A"]), to: .atIndex(parentID: nil, index: 2))
        #expect(result.count == 3)
        #expect(result[0].id == "B")
        #expect(result[1].id == "A")
        #expect(result[2].id == "C")
    }

    @Test("Move node to end")
    func moveToEnd() {
        let tree = [node("A"), node("B"), node("C")]
        let result = tree.movingNodes(ids: Set(["A"]), to: .atIndex(parentID: nil, index: 3))
        #expect(result.count == 3)
        #expect(result[0].id == "B")
        #expect(result[1].id == "C")
        #expect(result[2].id == "A")
    }

    @Test("Move into different parent")
    func moveIntoDifferentParent() {
        let tree = [node("P1", children: [node("A")]), node("P2", children: [node("B")])]
        let result = tree.movingNodes(ids: Set(["A"]), to: .atIndex(parentID: "P2", index: 0))
        #expect(result[0].children.isEmpty)
        #expect(result[1].children.count == 2)
        #expect(result[1].children[0].id == "A")
        #expect(result[1].children[1].id == "B")
    }

    // MARK: - Cycle Prevention

    @Test("Cannot drop parent into its own child")
    func cyclePreventionDirectChild() {
        let tree = [node("parent", children: [node("child")])]
        let allowed = tree.canDrop(draggedIDs: Set(["parent"]), onto: .intoSection("child"))
        #expect(allowed == false)
    }

    @Test("Can drop into unrelated node")
    func dropIntoUnrelated() {
        let tree = [node("A", children: [node("B")]), node("C")]
        let allowed = tree.canDrop(draggedIDs: Set(["B"]), onto: .intoSection("C"))
        #expect(allowed == true)
    }

    @Test("Can always drop at root level")
    func dropAtRoot() {
        let tree = [node("A", children: [node("B")])]
        let allowed = tree.canDrop(draggedIDs: Set(["A"]), onto: .atIndex(parentID: nil, index: 0))
        #expect(allowed == true)
    }

    @Test("Cannot drop into dragged section")
    func cannotDropIntoDraggedSection() {
        let tree = [node("A", isContainer: true, children: [node("B")])]
        let allowed = tree.canDrop(draggedIDs: Set(["A"]), onto: .intoSection("A"))
        #expect(allowed == false)
    }

    @Test("Cannot drop as child of dragged node")
    func cannotDropAsChildOfDragged() {
        let tree = [node("A", children: [node("B")]), node("C")]
        let allowed = tree.canDrop(draggedIDs: Set(["A"]), onto: .atIndex(parentID: "A", index: 0))
        #expect(allowed == false)
    }

    @Test("Cannot drop container into another section")
    func cannotDropContainerIntoSection() {
        let tree = [node("S1", isContainer: true, children: [node("A")]), node("S2", isContainer: true, children: [node("B")])]
        let allowed = tree.canDrop(draggedIDs: Set(["S1"]), onto: .intoSection("S2"))
        #expect(allowed == false)
    }

    @Test("Cannot drop container between items in another section")
    func cannotDropContainerBetweenChildrenOfSection() {
        let tree = [node("S1", isContainer: true), node("S2", isContainer: true, children: [node("A"), node("B")])]
        let allowed = tree.canDrop(draggedIDs: Set(["S1"]), onto: .atIndex(parentID: "S2", index: 1))
        #expect(allowed == false)
    }

    @Test("Cannot drop node with children into a section")
    func cannotDropNodeWithChildrenIntoSection() {
        let tree = [node("A", children: [node("X")]), node("B", isContainer: true)]
        let allowed = tree.canDrop(draggedIDs: Set(["A"]), onto: .intoSection("B"))
        #expect(allowed == false)
    }
}

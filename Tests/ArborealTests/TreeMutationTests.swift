import Testing
@testable import Arboreal

@Suite("Tree Mutation Tests")
struct TreeMutationTests {
    // MARK: - Extract

    @Test("Extract single node from roots")
    func extractFromRoots() {
        let tree = [node("A"), node("B"), node("C")]
        let (remaining, extracted) = extractNodes(from: tree, ids: Set(["B"]))
        #expect(remaining.count == 2)
        #expect(remaining[0].id == "A")
        #expect(remaining[1].id == "C")
        #expect(extracted.count == 1)
        #expect(extracted[0].id == "B")
    }

    @Test("Extract nested node")
    func extractNested() {
        let tree = [node("root", children: [node("child1"), node("child2")])]
        let (remaining, extracted) = extractNodes(from: tree, ids: Set(["child1"]))
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
        let result = insertNodes(into: tree, nodes: [node("B")], at: .rootLevel(index: 1))
        #expect(result.count == 3)
        #expect(result[0].id == "A")
        #expect(result[1].id == "B")
        #expect(result[2].id == "C")
    }

    @Test("Insert before node")
    func insertBefore() {
        let tree = [node("A"), node("C")]
        let result = insertNodes(into: tree, nodes: [node("B")], at: .before("C"))
        #expect(result.count == 3)
        #expect(result[1].id == "B")
        #expect(result[2].id == "C")
    }

    @Test("Insert after node")
    func insertAfter() {
        let tree = [node("A"), node("C")]
        let result = insertNodes(into: tree, nodes: [node("B")], at: .after("A"))
        #expect(result.count == 3)
        #expect(result[0].id == "A")
        #expect(result[1].id == "B")
    }

    @Test("Insert into container")
    func insertInto() {
        let tree = [node("parent", isContainer: true)]
        let result = insertNodes(into: tree, nodes: [node("child")], at: .intoSection("parent"))
        #expect(result[0].children.count == 1)
        #expect(result[0].children[0].id == "child")
    }

    // MARK: - Move

    @Test("Move node between siblings")
    func moveBetweenSiblings() {
        let tree = [node("A"), node("B"), node("C")]
        let result = moveNodes(in: tree, ids: Set(["C"]), to: .before("A"))
        #expect(result.count == 3)
        #expect(result[0].id == "C")
        #expect(result[1].id == "A")
        #expect(result[2].id == "B")
    }

    // MARK: - Cycle Prevention

    @Test("Cannot drop parent into its own child")
    func cyclePreventionDirectChild() {
        let tree = [node("parent", children: [node("child")])]
        let allowed = canDrop(in: tree, draggedIDs: Set(["parent"]), onto: .intoSection("child"))
        #expect(allowed == false)
    }

    @Test("Cannot drop ancestor into deep descendant")
    func cyclePreventionDeep() {
        let tree = [node("A", children: [node("B", children: [node("C")])])]
        let allowed = canDrop(in: tree, draggedIDs: Set(["A"]), onto: .intoSection("C"))
        #expect(allowed == false)
    }

    @Test("Can drop into unrelated node")
    func dropIntoUnrelated() {
        let tree = [node("A", children: [node("B")]), node("C")]
        let allowed = canDrop(in: tree, draggedIDs: Set(["B"]), onto: .intoSection("C"))
        #expect(allowed == true)
    }

    @Test("Can always drop at root level")
    func dropAtRoot() {
        let tree = [node("A", children: [node("B")])]
        let allowed = canDrop(in: tree, draggedIDs: Set(["A"]), onto: .rootLevel(index: 0))
        #expect(allowed == true)
    }

    @Test("Cannot drop node before itself")
    func cannotDropBeforeSelf() {
        let tree = [node("A"), node("B"), node("C")]
        let allowed = canDrop(in: tree, draggedIDs: Set(["B"]), onto: .before("B"))
        #expect(allowed == false)
    }

    @Test("Cannot drop node after itself")
    func cannotDropAfterSelf() {
        let tree = [node("A"), node("B"), node("C")]
        let allowed = canDrop(in: tree, draggedIDs: Set(["B"]), onto: .after("B"))
        #expect(allowed == false)
    }

    @Test("Cannot drop section into itself")
    func cannotDropSectionIntoSelf() {
        let tree = [node("A", isContainer: true, children: [node("B")])]
        let allowed = canDrop(in: tree, draggedIDs: Set(["A"]), onto: .intoSection("A"))
        #expect(allowed == false)
    }
}

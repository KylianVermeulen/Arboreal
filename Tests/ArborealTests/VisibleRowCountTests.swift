import Testing
@testable import Arboreal

@Suite("Visible Row Count Tests")
struct VisibleRowCountTests {
    @Test("Single leaf item counts as 1 row")
    func singleLeaf() {
        let tree = [node("A"), node("B"), node("C")]
        let entries = flattenTree(tree, expansionState: Set<String>())
        let count = visibleRowCount(for: .singleItem("B"), in: entries)
        #expect(count == 1)
    }

    @Test("Expanded section counts itself plus visible children")
    func expandedSection() {
        let tree = [node("S", isContainer: true, children: [node("A"), node("B"), node("C")])]
        let entries = flattenTree(tree, expansionState: Set(["S"]))
        let count = visibleRowCount(for: .section("S"), in: entries)
        #expect(count == 4)
    }

    @Test("Collapsed section counts as 1 row")
    func collapsedSection() {
        let tree = [node("S", isContainer: true, children: [node("A"), node("B"), node("C")])]
        let entries = flattenTree(tree, expansionState: Set<String>())
        let count = visibleRowCount(for: .section("S"), in: entries)
        #expect(count == 1)
    }

    @Test("Multi-select without overlap sums subtrees")
    func multiSelectNoOverlap() {
        let tree = [node("A"), node("B"), node("C")]
        let entries = flattenTree(tree, expansionState: Set<String>())
        let count = visibleRowCount(for: .multipleItems(Set(["A", "C"])), in: entries)
        #expect(count == 2)
    }

    @Test("Multi-select with ancestor and descendant avoids double-counting")
    func multiSelectWithAncestor() {
        let tree = [node("S", isContainer: true, children: [node("A"), node("B")])]
        let entries = flattenTree(tree, expansionState: Set(["S"]))
        // "S" covers A and B already, selecting "A" too should not double-count
        let count = visibleRowCount(for: .multipleItems(Set(["S", "A"])), in: entries)
        #expect(count == 3)
    }

    @Test("ID not in entries falls back to 1")
    func missingID() {
        let tree = [node("A")]
        let entries = flattenTree(tree, expansionState: Set<String>())
        let count = visibleRowCount(for: .singleItem("missing"), in: entries)
        #expect(count == 1)
    }

    @Test("Deeply nested expanded section counts all visible descendants")
    func deeplyNested() {
        let tree = [node("A", isContainer: true, children: [
            node("B", isContainer: true, children: [
                node("C"),
                node("D"),
            ]),
        ])]
        let entries = flattenTree(tree, expansionState: Set(["A", "B"]))
        let count = visibleRowCount(for: .section("A"), in: entries)
        #expect(count == 4) // A, B, C, D
    }

    @Test("Section with partially expanded children")
    func partiallyExpanded() {
        let tree = [node("A", isContainer: true, children: [
            node("B", isContainer: true, children: [node("C")]),
            node("D"),
        ])]
        // A is expanded, B is collapsed
        let entries = flattenTree(tree, expansionState: Set(["A"]))
        let count = visibleRowCount(for: .section("A"), in: entries)
        #expect(count == 3) // A, B, D (C is hidden because B is collapsed)
    }
}

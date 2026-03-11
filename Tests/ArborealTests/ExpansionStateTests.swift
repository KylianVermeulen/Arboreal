import Testing
@testable import Arboreal

@Suite("ExpansionState Tests")
struct ExpansionStateTests {
    @Test("Initial state is empty")
    @MainActor
    func initialState() {
        let state = ExpansionState<String>()
        #expect(state.expandedIDs.isEmpty)
        #expect(state.isExpanded("A") == false)
    }

    @Test("Expand and collapse")
    @MainActor
    func expandCollapse() {
        let state = ExpansionState<String>()
        state.expand("A")
        #expect(state.isExpanded("A") == true)
        state.collapse("A")
        #expect(state.isExpanded("A") == false)
    }

    @Test("Toggle")
    @MainActor
    func toggle() {
        let state = ExpansionState<String>()
        state.toggle("A")
        #expect(state.isExpanded("A") == true)
        state.toggle("A")
        #expect(state.isExpanded("A") == false)
    }

    @Test("Expand all")
    @MainActor
    func expandAll() {
        let state = ExpansionState<String>()
        state.expandAll(["A", "B", "C"])
        #expect(state.expandedIDs.count == 3)
    }

    @Test("Collapse all")
    @MainActor
    func collapseAll() {
        let state = ExpansionState<String>()
        state.expandAll(["A", "B"])
        state.collapseAll()
        #expect(state.expandedIDs.isEmpty)
    }

    @Test("Initial expanded IDs")
    @MainActor
    func initialExpandedIDs() {
        let state = ExpansionState<String>(expandedIDs: ["X", "Y"])
        #expect(state.isExpanded("X") == true)
        #expect(state.isExpanded("Y") == true)
        #expect(state.isExpanded("Z") == false)
    }
}

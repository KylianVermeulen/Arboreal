import Observation

@Observable
@MainActor
public final class ExpansionState<ID: Hashable & Sendable>: Sendable {
    public var expandedIDs: Set<ID>

    public init(expandedIDs: Set<ID> = []) {
        self.expandedIDs = expandedIDs
    }

    public func isExpanded(_ id: ID) -> Bool {
        expandedIDs.contains(id)
    }

    public func toggle(_ id: ID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    public func expand(_ id: ID) {
        expandedIDs.insert(id)
    }

    public func collapse(_ id: ID) {
        expandedIDs.remove(id)
    }

    public func expandAll(_ ids: some Sequence<ID>) {
        expandedIDs.formUnion(ids)
    }

    public func collapseAll() {
        expandedIDs.removeAll()
    }
}

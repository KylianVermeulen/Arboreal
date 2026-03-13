import Observation

/// Observable state tracking which tree nodes are expanded.
///
/// Pass an instance to ``TreeDragDropView`` to control which sections are open.
/// Mutations automatically trigger SwiftUI view updates.
@Observable
@MainActor
public final class ExpansionState<ID: Hashable & Sendable>: Sendable {
    /// The set of currently expanded node identifiers.
    public var expandedIDs: Set<ID>

    public init(expandedIDs: Set<ID> = []) {
        self.expandedIDs = expandedIDs
    }

    /// Returns whether the node with the given identifier is expanded.
    public func isExpanded(_ id: ID) -> Bool {
        expandedIDs.contains(id)
    }

    /// Toggles the expansion state of the node with the given identifier.
    public func toggle(_ id: ID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    /// Expands the node with the given identifier.
    public func expand(_ id: ID) {
        expandedIDs.insert(id)
    }

    /// Collapses the node with the given identifier.
    public func collapse(_ id: ID) {
        expandedIDs.remove(id)
    }

    /// Expands all nodes with the given identifiers.
    public func expandAll(_ ids: some Sequence<ID>) {
        expandedIDs.formUnion(ids)
    }

    /// Collapses all nodes.
    public func collapseAll() {
        expandedIDs.removeAll()
    }
}

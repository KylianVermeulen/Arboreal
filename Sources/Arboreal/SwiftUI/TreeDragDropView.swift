import SwiftUI

public struct TreeDragDropView<Content: TreeNodeContent, CellContent: View>: UIViewRepresentable where Content: Sendable, Content.ID: Sendable {
    @Binding var tree: [TreeNode<Content>]
    @Binding var selectedIDs: Set<Content.ID>
    var expansionState: ExpansionState<Content.ID>
    var configuration: TreeDragDropConfiguration<Content>
    @ViewBuilder var cellContent: @MainActor (FlatTreeEntry<Content>) -> CellContent

    public init(
        tree: Binding<[TreeNode<Content>]>,
        selectedIDs: Binding<Set<Content.ID>>,
        expansionState: ExpansionState<Content.ID>,
        configuration: TreeDragDropConfiguration<Content> = .init(),
        @ViewBuilder cellContent: @escaping @MainActor (FlatTreeEntry<Content>) -> CellContent
    ) {
        self._tree = tree
        self._selectedIDs = selectedIDs
        self.expansionState = expansionState
        self.configuration = configuration
        self.cellContent = cellContent
    }

    public func makeUIView(context: Context) -> TreeContainerView<Content> {
        let view = TreeContainerView<Content>(frame: .zero)
        view.configuration = configuration
        view.cellContentProvider = { entry in
            AnyView(cellContent(entry))
        }
        context.coordinator.containerView = view
        context.coordinator.updateEntries()
        return view
    }

    public func updateUIView(_ uiView: TreeContainerView<Content>, context: Context) {
        let coordinator = context.coordinator

        // Prevent re-entrant updates during drag
        guard !coordinator.isPerformingDrop else { return }

        coordinator.generation += 1
        uiView.configuration = configuration
        uiView.cellContentProvider = { entry in
            AnyView(cellContent(entry))
        }
        coordinator.tree = tree
        coordinator.selectedIDs = selectedIDs
        coordinator.expansionState = expansionState
        coordinator.updateEntries()
    }

    public func makeCoordinator() -> TreeDragDropCoordinator<Content, CellContent> {
        TreeDragDropCoordinator(view: self)
    }
}

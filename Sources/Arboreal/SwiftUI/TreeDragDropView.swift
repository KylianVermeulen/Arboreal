import SwiftUI

public struct TreeDragDropView<Content: TreeNodeContent, CellContent: View>: UIViewRepresentable where Content: Sendable, Content.ID: Sendable {
    @Binding var tree: [TreeNode<Content>]
    @Binding var selectedIDs: Set<Content.ID>
    var expansionState: ExpansionState<Content.ID>
    var configuration: TreeDragDropConfiguration<Content>
    @ViewBuilder var cellContent: @MainActor (Content, Int, Bool, Bool) -> CellContent

    public init(
        tree: Binding<[TreeNode<Content>]>,
        selectedIDs: Binding<Set<Content.ID>>,
        expansionState: ExpansionState<Content.ID>,
        configuration: TreeDragDropConfiguration<Content> = .init(),
        @ViewBuilder cellContent: @escaping @MainActor (Content, Int, Bool, Bool) -> CellContent
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
        let selectedIDs = selectedIDs
        view.cellContentProvider = { entry in
            AnyView(cellContent(entry.content, entry.depth, selectedIDs.contains(entry.id), entry.isExpanded))
        }
        context.coordinator.containerView = view
        view.installInteractions(dragDelegate: context.coordinator, dropDelegate: context.coordinator)
        context.coordinator.updateEntries()
        return view
    }

    public func updateUIView(_ uiView: TreeContainerView<Content>, context: Context) {
        let coordinator = context.coordinator

        // Prevent re-entrant updates during drag
        guard !coordinator.isPerformingDrop else { return }

        coordinator.generation += 1
        uiView.configuration = configuration
        let selectedIDs = selectedIDs
        let cellContent = cellContent
        uiView.cellContentProvider = { entry in
            AnyView(cellContent(entry.content, entry.depth, selectedIDs.contains(entry.id), entry.isExpanded))
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

import SwiftUI

/// A SwiftUI view that displays a tree of nodes with drag-and-drop reordering.
///
/// This is the main entry point for using Arboreal in SwiftUI. It bridges to a UIKit-based
/// scroll view for high-performance layout and native drag-and-drop interactions.
///
/// ```swift
/// TreeDragDropView(tree: tree, expansionState: expansionState) { item, depth, isSelected, isExpanded in
///     Text(item.title)
/// }
/// ```
public struct TreeDragDropView<Content: TreeNodeContent, CellContent: View>: UIViewRepresentable where Content: Sendable, Content.ID: Sendable {
    var tree: [TreeNode<Content>]
    var selectedIDs: Set<Content.ID>
    var expansionState: ExpansionState<Content.ID>
    var configuration: TreeDragDropConfiguration<Content>
    @ViewBuilder var cellContent: @MainActor (Content, Int, Bool, Bool) -> CellContent

    /// Creates a tree drag-and-drop view with selection tracking.
    ///
    /// - Parameters:
    ///   - tree: The array of root nodes.
    ///   - selectedIDs: The set of selected node identifiers.
    ///   - expansionState: The observable state tracking which nodes are expanded.
    ///   - configuration: Configuration for layout, behavior, and callbacks.
    ///   - cellContent: A view builder that produces the content for each row.
    ///     Parameters are: content, depth, isSelected, isExpanded.
    public init(
        tree: [TreeNode<Content>],
        selectedIDs: Set<Content.ID>,
        expansionState: ExpansionState<Content.ID>,
        configuration: TreeDragDropConfiguration<Content> = .init(),
        @ViewBuilder cellContent: @escaping @MainActor (Content, Int, Bool, Bool) -> CellContent
    ) {
        self.tree = tree
        self.selectedIDs = selectedIDs
        self.expansionState = expansionState
        self.configuration = configuration
        self.cellContent = cellContent
    }

    /// Creates a tree drag-and-drop view without selection tracking.
    ///
    /// - Parameters:
    ///   - tree: The array of root nodes.
    ///   - expansionState: The observable state tracking which nodes are expanded.
    ///   - configuration: Configuration for layout, behavior, and callbacks.
    ///   - cellContent: A view builder that produces the content for each row.
    ///     Parameters are: content, depth, isSelected, isExpanded.
    public init(
        tree: [TreeNode<Content>],
        expansionState: ExpansionState<Content.ID>,
        configuration: TreeDragDropConfiguration<Content> = .init(),
        @ViewBuilder cellContent: @escaping @MainActor (Content, Int, Bool, Bool) -> CellContent
    ) {
        self.tree = tree
        self.selectedIDs = Set()
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

        // Ask SwiftUI to re-query `sizeThatFits` when the tree changes so embedded mode
        // reflects expand/collapse and insertions/removals in the parent scroll view.
        if !configuration.scrollEnabled {
            uiView.invalidateIntrinsicContentSize()
        }
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: TreeContainerView<Content>,
        context: Context
    ) -> CGSize? {
        // When internal scrolling is enabled, let SwiftUI use its default behavior
        // (the scroll view fills the proposed size and handles its own scrolling).
        guard !configuration.scrollEnabled else { return nil }

        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let height = uiView.intrinsicContentHeight(forWidth: width)
        return CGSize(width: width, height: height)
    }

    public func makeCoordinator() -> TreeDragDropCoordinator<Content, CellContent> {
        TreeDragDropCoordinator(view: self)
    }
}

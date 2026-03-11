import SwiftUI
import Arboreal

// MARK: - Content Model

enum OutlineItem: TreeNodeContent {
    case section(id: UUID, title: String, icon: String)
    case task(id: UUID, title: String, priority: Priority, isCompleted: Bool)

    enum Priority: String, Hashable, Sendable, CaseIterable {
        case low, medium, high

        var color: Color {
            switch self {
            case .low: .green
            case .medium: .orange
            case .high: .red
            }
        }
    }

    var id: UUID {
        switch self {
        case .section(let id, _, _): id
        case .task(let id, _, _, _): id
        }
    }

    var isContainer: Bool {
        if case .section = self { true } else { false }
    }
}

// MARK: - Row Views

struct SectionRowView: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.tint)

            Text(title)
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct TaskRowView: View {
    let title: String
    let priority: OutlineItem.Priority
    let isCompleted: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? .green : .secondary)

            Text(title)
                .strikethrough(isCompleted)
                .foregroundStyle(isCompleted ? .secondary : .primary)

            Spacer()

            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var tree: [TreeNode<OutlineItem>] = makeSampleTree()
    @State private var selectedIDs: Set<UUID> = []
    @State private var expansionState = ExpansionState<UUID>()

    var body: some View {
        NavigationStack {
            TreeDragDropView(
                tree: $tree,
                selectedIDs: $selectedIDs,
                expansionState: expansionState,
                configuration: .exampleConfiguration(tree: tree)
            ) { item, depth, isSelected, isExpanded in
                switch item {
                case .section(let id, let title, let icon):
                    SectionRowView(
                        title: title,
                        icon: icon,
                        isExpanded: isExpanded,
                        isSelected: isSelected
                    )
                    .onTapGesture {
                        expansionState.toggle(id)
                    }

                case .task(let id, let title, let priority, let isCompleted):
                    TaskRowView(
                        title: title,
                        priority: priority,
                        isCompleted: isCompleted,
                        isSelected: isSelected
                    )
                    .onTapGesture {
                        if selectedIDs.contains(id) {
                            selectedIDs.remove(id)
                        } else {
                            selectedIDs.insert(id)
                        }
                    }
                }
            }
            .navigationTitle("Project Plan")
            .toolbarTitleDisplayMode(.large)
        }
        .onAppear {
            expansionState.expandAll(tree.map(\.id))
        }
    }
}

// MARK: - Configuration

extension TreeDragDropConfiguration where Content == OutlineItem {
    static func exampleConfiguration(tree: [TreeNode<OutlineItem>]) -> TreeDragDropConfiguration {
        var config = TreeDragDropConfiguration()
        config.rowHeight = 48
        config.indentationWidth = 24
        config.dropIndicatorStyle = .preview(DropPreviewTheme(
            fillColor: Color.blue.opacity(0.12),
            borderColor: Color.blue.opacity(0.3),
            borderWidth: 1,
            cornerRadius: 10
        ))
        config.canDropIntoSection = { _, payload in
            // Prevent sections from being nested inside other sections
            func isSection(_ id: UUID) -> Bool {
                func find(in nodes: [TreeNode<OutlineItem>]) -> Bool {
                    for node in nodes {
                        if node.id == id { return node.content.isContainer }
                        if find(in: node.children) { return true }
                    }
                    return false
                }
                return find(in: tree)
            }
            switch payload {
            case .singleItem(let id):
                return !isSection(id)
            case .section(let id):
                return !isSection(id)
            case .multipleItems(let ids):
                return !ids.contains(where: { isSection($0) })
            }
        }
        return config
    }
}

// MARK: - Sample Data

private func makeSampleTree() -> [TreeNode<OutlineItem>] {
    [
        TreeNode(
            content: .section(id: UUID(), title: "Design", icon: "paintbrush"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "Create wireframes", priority: .high, isCompleted: true)),
                TreeNode(content: .task(id: UUID(), title: "Design component library", priority: .medium, isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Review color palette", priority: .low, isCompleted: false)),
            ]
        ),
        TreeNode(
            content: .section(id: UUID(), title: "Development", icon: "chevron.left.forwardslash.chevron.right"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "Set up project structure", priority: .high, isCompleted: true)),
                TreeNode(content: .task(id: UUID(), title: "Implement drag and drop", priority: .high, isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Write unit tests", priority: .medium, isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Performance profiling", priority: .low, isCompleted: false)),
            ]
        ),
        TreeNode(
            content: .section(id: UUID(), title: "Launch", icon: "paperplane"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "Beta testing", priority: .medium, isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "App Store submission", priority: .high, isCompleted: false)),
            ]
        ),
    ]
}

#Preview {
    ContentView()
}

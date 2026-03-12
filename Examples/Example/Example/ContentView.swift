import SwiftUI
import Arboreal

// MARK: - Content Model

enum OutlineItem: TreeNodeContent {
    case section(id: UUID, title: String)
    case task(id: UUID, title: String, isCompleted: Bool)

    var id: UUID {
        switch self {
        case .section(let id, _): id
        case .task(let id, _, _): id
        }
    }

    var isContainer: Bool {
        if case .section = self { true } else { false }
    }
}

// MARK: - Row Views

struct SectionRowView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            Rectangle()
                .fill(Color.accentColor.opacity(0.4))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct TaskRowView: View {
    let title: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                .font(.body)
                .foregroundStyle(isCompleted ? Color.accentColor : Color(.systemGray3))

            Text(title)
                .font(.body)
                .foregroundStyle(isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var tree: [TreeNode<OutlineItem>] = makeSampleTree()
    @State private var selectedIDs: Set<UUID> = []
    @State private var expansionState = ExpansionState<UUID>()

    var body: some View {
        TreeDragDropView(
            tree: $tree,
            selectedIDs: $selectedIDs,
            expansionState: expansionState,
            configuration: .exampleConfiguration(tree: tree)
        ) { item, depth, isSelected, isExpanded in
            switch item {
            case .section(_, let title):
                SectionRowView(title: title)

            case .task(let id, let title, let isCompleted):
                TaskRowView(
                    title: title,
                    isCompleted: isCompleted
                )
                .onTapGesture {
                    toggleCompletion(id: id)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            expansionState.expandAll(tree.map(\.id))
        }
    }

    private func toggleCompletion(id: UUID) {
        func toggle(in nodes: inout [TreeNode<OutlineItem>]) {
            for i in nodes.indices {
                if case .task(let taskID, let title, let completed) = nodes[i].content, taskID == id {
                    nodes[i] = TreeNode(content: .task(id: taskID, title: title, isCompleted: !completed), children: [])
                    return
                }
                toggle(in: &nodes[i].children)
            }
        }
        toggle(in: &tree)
    }
}

// MARK: - Configuration

extension TreeDragDropConfiguration where Content == OutlineItem {
    static func exampleConfiguration(tree: [TreeNode<OutlineItem>]) -> TreeDragDropConfiguration {
        var config = TreeDragDropConfiguration()
        config.rowHeight = 44
        config.indentationWidth = 0
        config.dropIndicatorStyle = .preview(DropPreviewTheme(
            fillColor: Color(red: 0x16/255.0, green: 0x20/255.0, blue: 0x2C/255.0),
            borderColor: nil,
            borderWidth: 0,
            cornerRadius: 10,
            horizontalPadding: 16
        ))
        config.canDropIntoSection = { _, payload in
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
            case .singleItem(let id), .section(let id):
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
            content: .section(id: UUID(), title: "Reflect on Core Values and Beliefs"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "Write down my core values and what they mean to me", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Reflect on the qualities I admire in others and the principles I live by", isCompleted: false)),
            ]
        ),
        TreeNode(
            content: .section(id: UUID(), title: "Identify Key Strengths and Passions"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "List my strengths and what I'm most passionate about", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Reflect on past successes and moments when I felt most fulfilled", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Think about how I want to use these strengths to contribute", isCompleted: false)),
            ]
        ),
        TreeNode(
            content: .section(id: UUID(), title: "Define Purpose and Goals"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "Clarify what drives me and what I want to achieve in life", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Write down the key goals that align with my values, strengths, and passions", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Visualize my ideal future and the steps I need to take to get there", isCompleted: false)),
            ]
        ),
        TreeNode(
            content: .section(id: UUID(), title: "Draft and Refine Mission Statement"),
            children: [
                TreeNode(content: .task(id: UUID(), title: "Write a first draft of my personal mission statement", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Review and revise the statement to ensure it aligns with my values and goals", isCompleted: false)),
                TreeNode(content: .task(id: UUID(), title: "Ask for feedback from trusted friends or mentors to refine it further", isCompleted: false)),
            ]
        ),
    ]
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

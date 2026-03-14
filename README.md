# Arboreal

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKylianVermeulen%2FArboreal%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/KylianVermeulen/Arboreal)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKylianVermeulen%2FArboreal%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/KylianVermeulen/Arboreal)

A tree-structured drag-and-drop library for iOS. UIKit handles the heavy lifting for smooth, native interactions. SwiftUI gets a thin bridge layer so you can drop it into your views with a single component.

## Features

- Drag and drop to reorder items within and across sections
- Self-sizing rows based on SwiftUI content
- Multi-selection drag support
- Collapsible sections with observable expansion state
- Live drop preview indicator with customizable theming
- Floating drag view that follows your finger
- Haptic feedback on drag, drop, hover, and error events
- Per-item and per-target validation callbacks
- Pure-function tree mutations (extract, insert, move)
- Zero external dependencies

## Requirements

- iOS 18+
- Swift 6.2+
- Xcode 26+

## Installation

Add Arboreal via Swift Package Manager:

```
https://github.com/kylianvermeulen/Arboreal.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kylianvermeulen/Arboreal.git", from: "0.3.0")
]
```

## Quick Start

### 1. Define your content model

```swift
import Arboreal

struct Task: TreeNodeContent {
    let id: UUID
    let title: String
    var isContainer: Bool { false }
}
```

### 2. Build a tree

```swift
@State private var tree: [TreeNode<Task>] = [
    TreeNode(
        content: Task(id: UUID(), title: "Section"),
        children: [
            TreeNode(content: Task(id: UUID(), title: "Item A")),
            TreeNode(content: Task(id: UUID(), title: "Item B")),
        ]
    )
]

@State private var expansionState = ExpansionState<UUID>()
```

### 3. Use `TreeDragDropView`

```swift
TreeDragDropView(
    tree: tree,
    expansionState: expansionState
) { item, depth, isSelected, isExpanded in
    Text(item.title)
        .padding(.leading, CGFloat(depth) * 20)
}
```

## Configuration

Customize behavior through `TreeDragDropConfiguration`:

```swift
var config = TreeDragDropConfiguration<Task>()
config.indentationWidth = 24
config.canDrag = { item in !item.isContainer }
config.onReorder = { newTree in save(newTree) }
config.dropPreviewTheme = DropPreviewTheme(
    fillColor: .blue.opacity(0.12),
    cornerRadius: 10,
    horizontalPadding: 16
)

TreeDragDropView(
    tree: tree,
    expansionState: expansionState,
    configuration: config
) { item, depth, isSelected, isExpanded in
    // ...
}
```

## Key Types

| Type | Description |
|------|-------------|
| `TreeNodeContent` | Protocol your content model conforms to |
| `TreeNode` | A tree node with content and children (max depth 1) |
| `TreeDragDropView` | The main SwiftUI view |
| `TreeDragDropConfiguration` | Layout, behavior, and callback settings |
| `ExpansionState` | Observable state tracking expanded sections |
| `DropPreviewTheme` | Drop indicator appearance |
| `HapticConfiguration` | Haptic feedback toggles |
| `FlatTreeEntry` | Flattened row representation used for layout |
| `DropTarget` | Where a drop lands (`.atIndex` or `.intoSection`) |
| `DragPayload` | What is being dragged (`.singleItem`, `.multipleItems`, `.section`) |

## Tree Mutations

Pure functions on `[TreeNode]` for programmatic tree manipulation:

```swift
// Extract nodes by ID
let (remaining, extracted) = tree.extractingNodes(ids: selectedIDs)

// Insert at a target position
let updated = tree.insertingNodes(nodes, at: .atIndex(parentID: sectionID, index: 0))

// Move nodes to a new position
let moved = tree.movingNodes(ids: selectedIDs, to: .intoSection(sectionID))

// Check if a drop is valid
let allowed = tree.canDrop(draggedIDs: selectedIDs, onto: target)

// Flatten for layout
let entries = tree.flattened(expansionState: expansionState.expandedIDs)
```

## Example

See [`Examples/Example/`](Examples/Example/) for a working demo showing sections, tasks, expansion, and reordering.

## License

MIT -- see [LICENSE](LICENSE).

import SwiftUI
import Testing
import UIKit

@testable import Arboreal

@Suite("TreeContainerView Embedded Mode Tests")
struct TreeContainerEmbeddedTests {
    @Test("Configuration defaults to scrollEnabled = true")
    func defaultScrollEnabled() {
        let config = TreeDragDropConfiguration<TestContent>()
        #expect(config.scrollEnabled == true)
    }

    @Test("Setting scrollEnabled=false disables the underlying UIScrollView")
    @MainActor
    func scrollEnabledDisablesUIScrollView() {
        let view = TreeContainerView<TestContent>(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        var config = TreeDragDropConfiguration<TestContent>()
        config.scrollEnabled = false
        view.configuration = config

        #expect(view.isScrollEnabled == false)
        #expect(view.alwaysBounceVertical == false)
    }

    @Test("Flipping scrollEnabled back to true re-enables the UIScrollView")
    @MainActor
    func scrollEnabledReEnablesUIScrollView() {
        let view = TreeContainerView<TestContent>(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        var config = TreeDragDropConfiguration<TestContent>()
        config.scrollEnabled = false
        view.configuration = config

        config.scrollEnabled = true
        view.configuration = config

        #expect(view.isScrollEnabled == true)
        #expect(view.alwaysBounceVertical == true)
    }

    @Test("intrinsicContentHeight returns 0 for an empty tree")
    @MainActor
    func intrinsicContentHeightEmpty() {
        let view = TreeContainerView<TestContent>(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.cellContentProvider = { _ in AnyView(Color.clear.frame(height: 44)) }

        #expect(view.intrinsicContentHeight(forWidth: 320) == 0)
    }

    @Test("intrinsicContentHeight returns 0 when width is non-positive")
    @MainActor
    func intrinsicContentHeightZeroWidth() {
        let view = TreeContainerView<TestContent>(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.cellContentProvider = { _ in AnyView(Color.clear.frame(height: 44)) }

        let tree: [TreeNode<TestContent>] = [node("a"), node("b")]
        view.updateEntries(tree.flattened(expansionState: Set<String>()))

        #expect(view.intrinsicContentHeight(forWidth: 0) == 0)
    }

    @Test("intrinsicContentHeight sums row heights and node spacing for a populated tree")
    @MainActor
    func intrinsicContentHeightPopulated() {
        let view = TreeContainerView<TestContent>(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        var config = TreeDragDropConfiguration<TestContent>()
        config.scrollEnabled = false
        config.nodeSpacing = 8
        view.configuration = config
        view.cellContentProvider = { _ in AnyView(Color.clear.frame(height: 44)) }

        let tree: [TreeNode<TestContent>] = [node("a"), node("b"), node("c")]
        view.updateEntries(tree.flattened(expansionState: Set<String>()))

        // 3 rows × 44 + 2 inter-row spacings × 8 = 148
        #expect(view.intrinsicContentHeight(forWidth: 320) == 148)
    }
}

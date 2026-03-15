import CoreFoundation
import Testing

@testable import Arboreal

@Suite("Preview Layout Spacing Tests")
struct PreviewLayoutTests {
    let h: CGFloat = 44
    let s: CGFloat = 8

    @Test("Spacing between entries with gap at start")
    func spacingWithGapAtStart() {
        let tree = [node("A"), node("B"), node("C")]
        let entries = tree.flattened(expansionState: Set<String>())

        let layout = computePreviewLayout(
            entries: entries,
            target: .atIndex(parentID: nil, index: 0),
            payload: .singleItem("A"),
            heightForEntry: { _ in h },
            nodeSpacing: s
        )

        // Non-dragged: [B, C]. Gap before B.
        // Visual: gap(44) | sp(8) | B(44) | sp(8) | C(44)
        #expect(layout.gapY == 0)
        #expect(layout.gapHeight == h)
        #expect(layout.entryYPositions["B"] == h + s)
        #expect(layout.entryYPositions["C"] == h + s + h + s)
    }

    @Test("Spacing between entries with gap in middle")
    func spacingWithGapInMiddle() {
        let tree = [node("A"), node("B"), node("C")]
        let entries = tree.flattened(expansionState: Set<String>())

        let layout = computePreviewLayout(
            entries: entries,
            target: .atIndex(parentID: nil, index: 1),
            payload: .singleItem("B"),
            heightForEntry: { _ in h },
            nodeSpacing: s
        )

        // Non-dragged: [A, C]. Gap between A and C.
        // Visual: A(44) | sp(8) | gap(44) | sp(8) | C(44)
        #expect(layout.entryYPositions["A"] == 0)
        #expect(layout.gapY == h + s)
        #expect(layout.entryYPositions["C"] == h + s + h + s)
    }

    @Test("Spacing between entries with gap at end")
    func spacingWithGapAtEnd() {
        let tree = [node("A"), node("B"), node("C")]
        let entries = tree.flattened(expansionState: Set<String>())

        let layout = computePreviewLayout(
            entries: entries,
            target: .atIndex(parentID: nil, index: 3),
            payload: .singleItem("A"),
            heightForEntry: { _ in h },
            nodeSpacing: s
        )

        // Non-dragged: [B, C]. Gap at end.
        // Visual: B(44) | sp(8) | C(44) | sp(8) | gap(44)
        #expect(layout.entryYPositions["B"] == 0)
        #expect(layout.entryYPositions["C"] == h + s)
        #expect(layout.gapY == h + s + h + s)
    }

    @Test("Zero spacing produces same layout as default")
    func zeroSpacingRegression() {
        let tree = [node("A"), node("B"), node("C")]
        let entries = tree.flattened(expansionState: Set<String>())

        let layout = computePreviewLayout(
            entries: entries,
            target: .atIndex(parentID: nil, index: 1),
            payload: .singleItem("B"),
            heightForEntry: { _ in h },
            nodeSpacing: 0
        )

        // Non-dragged: [A, C]. Gap between A and C.
        // Visual: A(44) | gap(44) | C(44)
        #expect(layout.entryYPositions["A"] == 0)
        #expect(layout.gapY == h)
        #expect(layout.gapHeight == h)
        #expect(layout.entryYPositions["C"] == h + h)
    }
}

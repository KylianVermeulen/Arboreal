import SwiftUI

public struct DropIndicatorTheme: Sendable {
    public var lineColor: Color
    public var lineWidth: CGFloat
    public var highlightColor: Color
    public var cornerRadius: CGFloat

    public init(
        lineColor: Color = .accentColor,
        lineWidth: CGFloat = 2,
        highlightColor: Color = Color.accentColor.opacity(0.1),
        cornerRadius: CGFloat = 8
    ) {
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.highlightColor = highlightColor
        self.cornerRadius = cornerRadius
    }

    public static let `default` = DropIndicatorTheme()
}

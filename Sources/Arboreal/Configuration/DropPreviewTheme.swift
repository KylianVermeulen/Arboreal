import SwiftUI

public struct DropPreviewTheme: Sendable {
    public var fillColor: Color
    public var borderColor: Color?
    public var borderWidth: CGFloat
    public var cornerRadius: CGFloat
    public var horizontalPadding: CGFloat

    public init(
        fillColor: Color = Color.blue.opacity(0.12),
        borderColor: Color? = Color.blue.opacity(0.3),
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = 8,
        horizontalPadding: CGFloat = 0
    ) {
        self.fillColor = fillColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
    }

    public static let `default` = DropPreviewTheme()
}

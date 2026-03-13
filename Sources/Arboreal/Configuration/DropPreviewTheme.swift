import SwiftUI

/// Styling for the drop indicator shown at the target position during a drag.
public struct DropPreviewTheme: Sendable {
    /// The fill color of the drop indicator.
    public var fillColor: Color
    /// The border color, or `nil` for no border.
    public var borderColor: Color?
    /// The border width in points.
    public var borderWidth: CGFloat
    /// The corner radius of the drop indicator.
    public var cornerRadius: CGFloat
    /// Horizontal inset from the edges of the row.
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

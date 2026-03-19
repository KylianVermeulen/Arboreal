import SwiftUI

/// Styling for the floating drag view that follows the user's finger during a drag.
public struct FloatingDragStyle: Sendable {
    /// Background color applied to the floating view. Defaults to a dark blue.
    public var backgroundColor: UIColor
    /// Corner radius of the floating view. Defaults to 10.
    public var cornerRadius: CGFloat
    /// Shadow color. Defaults to black.
    public var shadowColor: UIColor
    /// Shadow opacity. Defaults to 0.25.
    public var shadowOpacity: Float
    /// Shadow blur radius in points. Defaults to 12.
    public var shadowRadius: CGFloat
    /// Shadow offset. Defaults to (0, 4).
    public var shadowOffset: CGSize
    /// Scale factor applied on lift. Defaults to 1.03.
    public var liftScale: CGFloat

    public init(
        backgroundColor: UIColor = UIColor(red: 0x1A / 255.0, green: 0x40 / 255.0, blue: 0x78 / 255.0, alpha: 1),
        cornerRadius: CGFloat = 10,
        shadowColor: UIColor = .black,
        shadowOpacity: Float = 0.25,
        shadowRadius: CGFloat = 12,
        shadowOffset: CGSize = CGSize(width: 0, height: 4),
        liftScale: CGFloat = 1.03
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.liftScale = liftScale
    }

    public static let `default` = FloatingDragStyle()
}

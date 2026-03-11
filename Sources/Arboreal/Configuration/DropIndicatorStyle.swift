import SwiftUI

public enum DropIndicatorStyle: Sendable {
    case `default`
    case themed(DropIndicatorTheme)
    case custom(@MainActor @Sendable (CGRect, DropIndicatorPosition) -> AnyView)

    public enum DropIndicatorPosition: Sendable {
        case above
        case below
        case inside
    }
}

public protocol TreeNodeContent: Identifiable, Hashable, Sendable where ID: Sendable {
    var isContainer: Bool { get }
}

extension TreeNodeContent {
    public var isContainer: Bool { false }
}

import UIKit

@MainActor
final class ViewReusePool<Cell: UIView> {
    private var available: [Cell] = []
    private var inUse: [AnyHashable: Cell] = [:]
    private let factory: () -> Cell

    init(factory: @escaping () -> Cell) {
        self.factory = factory
    }

    func dequeue(for key: AnyHashable) -> Cell {
        if let existing = inUse[key] {
            return existing
        }
        let cell: Cell
        if let recycled = available.popLast() {
            cell = recycled
        } else {
            cell = factory()
        }
        inUse[key] = cell
        return cell
    }

    func recycle(for key: AnyHashable) {
        if let cell = inUse.removeValue(forKey: key) {
            available.append(cell)
        }
    }

    func recycleAll(except keys: Set<AnyHashable>) {
        let toRecycle = inUse.keys.filter { !keys.contains($0) }
        for key in toRecycle {
            recycle(for: key)
        }
    }

    func reset() {
        available.append(contentsOf: inUse.values)
        inUse.removeAll()
    }

    func cell(for key: AnyHashable) -> Cell? {
        inUse[key]
    }

    var activeKeys: Set<AnyHashable> {
        Set(inUse.keys)
    }
}

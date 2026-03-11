import UIKit

@MainActor
final class MultiItemPreviewView: UIView {
    private let stackOffset: CGFloat = 4
    private let maxVisibleCards = 3

    init(itemViews: [UIView], totalCount: Int) {
        super.init(frame: .zero)
        setup(itemViews: itemViews, totalCount: totalCount)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(itemViews: [UIView], totalCount: Int) {
        let visibleViews = Array(itemViews.prefix(maxVisibleCards))

        guard let firstView = visibleViews.first else { return }

        let intrinsic = firstView.intrinsicContentSize
        let baseSize =
            intrinsic != CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
            ? intrinsic
            : CGSize(width: 200, height: 44)

        let totalOffset = CGFloat(visibleViews.count - 1) * stackOffset
        let frameSize = CGSize(
            width: baseSize.width + totalOffset,
            height: baseSize.height + totalOffset
        )
        frame = CGRect(origin: .zero, size: frameSize)

        // Add views in reverse order so the first item is on top
        for (index, view) in visibleViews.enumerated().reversed() {
            let offset = CGFloat(index) * stackOffset
            view.frame = CGRect(
                x: offset,
                y: offset,
                width: baseSize.width,
                height: baseSize.height
            )
            view.layer.cornerRadius = 8
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.15
            view.layer.shadowOffset = CGSize(width: 0, height: 2)
            view.layer.shadowRadius = 4
            addSubview(view)
        }

        // Add badge if count > 1
        if totalCount > 1 {
            let badge = makeBadge(count: totalCount)
            addSubview(badge)
            badge.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: topAnchor, constant: -8),
                badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
                badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
                badge.heightAnchor.constraint(equalToConstant: 24),
            ])
        }
    }

    private func makeBadge(count: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemRed
        container.layer.cornerRadius = 12

        let label = UILabel()
        label.text = "\(count)"
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
        ])

        return container
    }
}

import UIKit
import SwiftUI

@MainActor
final class TreeNodeCell: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure<V: View>(with content: V) {
        // Find or create the content view that supports UIHostingConfiguration
        let hostView: _UIHostingConfigurationBackingView
        if let existing = subviews.first(where: { $0 is _UIHostingConfigurationBackingView }) as? _UIHostingConfigurationBackingView {
            hostView = existing
        } else {
            hostView = _UIHostingConfigurationBackingView(frame: bounds)
            hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(hostView)
        }
        hostView.configuration = UIHostingConfiguration {
            content
        }
        .margins(.all, 0)
    }

    func prepareForReuse() {
        subviews.forEach { ($0 as? _UIHostingConfigurationBackingView)?.configuration = nil }
    }
}

/// Internal UIView subclass that applies UIHostingConfiguration as its contentConfiguration.
@MainActor
private final class _UIHostingConfigurationBackingView: UIView {
    var configuration: UIContentConfiguration? {
        didSet {
            if let configuration {
                if let existing = contentView {
                    existing.configuration = configuration
                } else {
                    let view = configuration.makeContentView()
                    view.frame = bounds
                    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    addSubview(view)
                    contentView = view
                }
            } else {
                contentView?.removeFromSuperview()
                contentView = nil
            }
        }
    }

    private var contentView: (UIView & UIContentView)?
}

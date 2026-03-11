import UIKit
import SwiftUI

@MainActor
final class TreeNodeCell: UIView {
    private var hostingController: UIHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure<V: View>(with content: V) {
        if let hostingController {
            hostingController.rootView = AnyView(content)
        } else {
            let controller = UIHostingController(rootView: AnyView(content))
            controller.view.backgroundColor = .clear
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(controller.view)
            NSLayoutConstraint.activate([
                controller.view.topAnchor.constraint(equalTo: topAnchor),
                controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
                controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            hostingController = controller
        }
    }

    func prepareForReuse() {
        hostingController?.rootView = AnyView(EmptyView())
    }
}

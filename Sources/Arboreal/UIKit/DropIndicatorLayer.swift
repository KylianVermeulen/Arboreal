import UIKit

@MainActor
final class DropIndicatorLayer: CAShapeLayer {
    func update(
        for rect: CGRect,
        fillColor fill: UIColor,
        borderColor border: UIColor?,
        borderWidth: CGFloat,
        cornerRadius: CGFloat,
        animated: Bool = true
    ) {
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.15)
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(name: .easeInEaseOut)
            )
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
        }

        let previewPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        self.path = previewPath.cgPath
        fillColor = fill.cgColor
        strokeColor = border?.cgColor
        lineWidth = border != nil ? borderWidth : 0
        sublayers?.forEach { $0.removeFromSuperlayer() }

        CATransaction.commit()
    }

    func hide() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(name: .easeOut)
        )
        path = nil
        sublayers?.forEach { $0.removeFromSuperlayer() }
        CATransaction.commit()
    }
}

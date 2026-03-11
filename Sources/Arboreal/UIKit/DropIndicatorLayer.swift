import UIKit

@MainActor
final class DropIndicatorLayer: CAShapeLayer {
    enum Style {
        case line(color: UIColor, width: CGFloat)
        case highlight(color: UIColor, cornerRadius: CGFloat)
    }

    func update(for rect: CGRect, style: Style, animated: Bool = true) {
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

        switch style {
        case .line(let color, let width):
            let y = rect.midY
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: rect.minX, y: y))
            linePath.addLine(to: CGPoint(x: rect.maxX, y: y))
            self.path = linePath.cgPath
            strokeColor = color.cgColor
            fillColor = nil
            lineWidth = width

            // Add circle at leading edge
            let circleRadius: CGFloat = width * 2
            let circlePath = UIBezierPath(
                arcCenter: CGPoint(x: rect.minX + circleRadius, y: y),
                radius: circleRadius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            let circleLayer: CAShapeLayer
            if let existing = sublayers?.first as? CAShapeLayer {
                circleLayer = existing
            } else {
                circleLayer = CAShapeLayer()
                sublayers?.forEach { $0.removeFromSuperlayer() }
                addSublayer(circleLayer)
            }
            circleLayer.path = circlePath.cgPath
            circleLayer.fillColor = color.cgColor

        case .highlight(let color, let cornerRadius):
            let highlightPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            self.path = highlightPath.cgPath
            strokeColor = nil
            fillColor = color.cgColor
            sublayers?.forEach { $0.removeFromSuperlayer() }
        }

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

import UIKit

/// Plain-UIKit replacement for the SwiftUI `ZTAIDiscoveryHintView` overlay, used only for
/// the table-screen "tap here" nudge. The SwiftUI version (a `UIHostingController` added
/// directly to the window, with a `repeatForever` pulse animation) reliably froze the app
/// the moment it first appeared — a known class of bug where a repeatForever animation
/// starting on the same render as the view's own appearance can send SwiftUI's animation
/// engine into a runaway recalculation loop that pins the main thread. Two attempts at
/// decoupling the animation inside SwiftUI didn't resolve it, so this sidesteps SwiftUI
/// entirely: a UIView ring pulsed with plain `UIView.animate(options: [.repeat, .autoreverse])`
/// and a UIView bubble, both APIs with no such reentrancy history.
final class FPRowAutofillDiscoveryHintView: UIView {
    private let ringView = UIView()
    private let bubbleContainer = UIView()
    private let arrowLayer = CAShapeLayer()
    private var onDismiss: (() -> Void)?
    private var autoDismissWorkItem: DispatchWorkItem?

    private static let accent = UIColor(red: 0x0B / 255, green: 0x6B / 255, blue: 0xEF / 255, alpha: 1)

    @discardableResult
    static func show(
        in window: UIWindow,
        targetFrame: CGRect,
        text: String,
        tag: Int,
        autoDismissAfter: TimeInterval = 6.0,
        onDismiss: @escaping () -> Void
    ) -> FPRowAutofillDiscoveryHintView {
        let overlay = FPRowAutofillDiscoveryHintView(frame: window.bounds)
        overlay.tag = tag
        overlay.backgroundColor = .clear
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onDismiss = onDismiss
        window.addSubview(overlay)
        overlay.configure(targetFrame: targetFrame, text: text, screenSize: window.bounds.size)
        overlay.scheduleAutoDismiss(after: autoDismissAfter)
        return overlay
    }

    private func configure(targetFrame: CGRect, text: String, screenSize: CGSize) {
        let ringFrame = targetFrame.insetBy(dx: -8, dy: -8)
        ringView.frame = ringFrame
        ringView.layer.borderWidth = 2.5
        ringView.layer.borderColor = Self.accent.cgColor
        ringView.layer.cornerRadius = 14
        ringView.isUserInteractionEnabled = false
        addSubview(ringView)
        startPulse()

        let below = targetFrame.midY < screenSize.height * 0.6

        let icon = UIImageView(image: UIImage(systemName: "hand.tap.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        bubbleContainer.backgroundColor = Self.accent
        bubbleContainer.layer.cornerRadius = 12
        bubbleContainer.layer.shadowColor = UIColor.black.cgColor
        bubbleContainer.layer.shadowOpacity = 0.22
        bubbleContainer.layer.shadowRadius = 14
        bubbleContainer.layer.shadowOffset = CGSize(width: 0, height: 6)
        addSubview(bubbleContainer)
        bubbleContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            stack.leadingAnchor.constraint(equalTo: bubbleContainer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: bubbleContainer.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: bubbleContainer.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bubbleContainer.bottomAnchor, constant: -10),
        ])

        let hPad: CGFloat = 16
        let maxWidth = min(screenSize.width - hPad * 2, 280)
        bubbleContainer.setNeedsLayout()
        bubbleContainer.layoutIfNeeded()
        let fitSize = bubbleContainer.systemLayoutSizeFitting(
            CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let bubbleWidth = min(fitSize.width, maxWidth)

        let leadingX = max(hPad, min(targetFrame.midX - bubbleWidth / 2, screenSize.width - hPad - bubbleWidth))
        let arrowH: CGFloat = 8
        let bubbleY = below ? ringFrame.maxY + arrowH : ringFrame.minY - arrowH - fitSize.height
        bubbleContainer.frame = CGRect(x: leadingX, y: bubbleY, width: bubbleWidth, height: fitSize.height)

        let arrowX = max(20, min(targetFrame.midX - leadingX, bubbleWidth - 20))
        let arrowPath = UIBezierPath()
        if below {
            arrowPath.move(to: CGPoint(x: arrowX - 8, y: 0))
            arrowPath.addLine(to: CGPoint(x: arrowX, y: -arrowH))
            arrowPath.addLine(to: CGPoint(x: arrowX + 8, y: 0))
        } else {
            arrowPath.move(to: CGPoint(x: arrowX - 8, y: fitSize.height))
            arrowPath.addLine(to: CGPoint(x: arrowX, y: fitSize.height + arrowH))
            arrowPath.addLine(to: CGPoint(x: arrowX + 8, y: fitSize.height))
        }
        arrowPath.close()
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = Self.accent.cgColor
        bubbleContainer.layer.addSublayer(arrowLayer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func startPulse() {
        UIView.animate(
            withDuration: 1.1,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut],
            animations: { [weak self] in
                self?.ringView.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            }
        )
    }

    private func scheduleAutoDismiss(after seconds: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        autoDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    @objc private func handleTap() {
        dismiss()
    }

    private func dismiss() {
        autoDismissWorkItem?.cancel()
        ringView.layer.removeAllAnimations()
        onDismiss?()
        removeFromSuperview()
    }
}

import AppKit

final class OverlayPanel {
    static let shared = OverlayPanel()
    private init() {}

    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(action: SemanticAction) {
        DispatchQueue.main.async { [weak self] in
            self?.present(action)
        }
    }

    private func present(_ action: SemanticAction) {
        hideTimer?.invalidate()
        panel?.close()

        let text = "\(action.menuTitle) faster:  \(action.shortcut)"
        let label = makeLabel(text)

        let padding = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        let contentSize = NSSize(
            width: label.intrinsicContentSize.width + padding.left + padding.right,
            height: label.intrinsicContentSize.height + padding.top + padding.bottom
        )

        let container = NSView(frame: NSRect(origin: .zero, size: contentSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.88).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true

        label.frame = NSRect(
            x: padding.left,
            y: padding.bottom,
            width: label.intrinsicContentSize.width,
            height: label.intrinsicContentSize.height
        )
        container.addSubview(label)

        let origin = panelOrigin(size: contentSize)
        let p = NSPanel(
            contentRect: NSRect(origin: origin, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.contentView = container
        p.alphaValue = 0
        p.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 1
        }

        panel = p
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            p.animator().alphaValue = 0
        }, completionHandler: { p.close() })
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .systemFont(ofSize: 14, weight: .medium)
        f.textColor = .white
        f.alignment = .center
        return f
    }

    private func panelOrigin(size: NSSize) -> NSPoint {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main!
        let sf = screen.visibleFrame
        let x = min(cursor.x + 16, sf.maxX - size.width - 8)
        let y = max(cursor.y - size.height - 16, sf.minY + 8)
        return NSPoint(x: x, y: y)
    }
}

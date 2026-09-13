import AppKit

final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class SelectionView: NSView {
    private let screenshot: CGImage
    private var selection = CGRect.zero
    private var anchor = CGPoint.zero
    private var original = CGRect.zero
    private var moving = false
    private var resizing = false
    private let confirm = NSButton(title: "Translate ↵", target: nil, action: nil)
    private let cancel = NSButton(title: "Cancel esc", target: nil, action: nil)
    var onCancel: (() -> Void)?
    var onConfirm: ((CGRect) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    init(frame: CGRect, screenshot: CGImage) {
        self.screenshot = screenshot
        super.init(frame: frame)
        confirm.target = self
        confirm.action = #selector(submit)
        cancel.target = self
        cancel.action = #selector(dismiss)
        for button in [confirm, cancel] {
            button.bezelStyle = .rounded
            addSubview(button)
        }
        confirm.isHidden = true
        cancel.frame = CGRect(x: bounds.midX - 50, y: 24, width: 100, height: 32)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        NSImage(cgImage: screenshot, size: bounds.size).draw(in: bounds)
        let shade = NSBezierPath(rect: bounds)
        if !selection.isEmpty { shade.append(NSBezierPath(rect: selection)) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.48).setFill()
        shade.fill()
        if !selection.isEmpty {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 2
            border.stroke()
            NSColor.white.setFill()
            for point in corners {
                NSBezierPath(ovalIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill()
            }
        }
        let message = "Drag to select • Drag inside to move • Drag corners to resize • Space or Return to translate • Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.white]
        let width = (message as NSString).size(withAttributes: attributes).width
        (message as NSString).draw(at: CGPoint(x: max(16, bounds.midX - width / 2), y: bounds.height - 56), withAttributes: attributes)
    }

    private var corners: [CGPoint] {
        [CGPoint(x: selection.minX, y: selection.minY), CGPoint(x: selection.maxX, y: selection.minY), CGPoint(x: selection.minX, y: selection.maxY), CGPoint(x: selection.maxX, y: selection.maxY)]
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        anchor = convert(event.locationInWindow, from: nil)
        original = selection
        resizing = false
        if !selection.isEmpty, let corner = corners.first(where: { hypot($0.x - anchor.x, $0.y - anchor.y) < 12 }) {
            anchor = CGPoint(x: corner.x == selection.minX ? selection.maxX : selection.minX,
                             y: corner.y == selection.minY ? selection.maxY : selection.minY)
            resizing = true
        }
        moving = !resizing && selection.contains(anchor)
        if !moving && !resizing { selection = .zero; updateButtons() }
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        let raw = convert(event.locationInWindow, from: nil)
        let point = CGPoint(x: min(max(raw.x, 0), bounds.width), y: min(max(raw.y, 0), bounds.height))
        if moving {
            selection.origin = CGPoint(x: min(max(original.minX + point.x - anchor.x, 0), bounds.width - original.width),
                                       y: min(max(original.minY + point.y - anchor.y, 0), bounds.height - original.height))
        } else {
            selection = CGRect(x: min(anchor.x, point.x), y: min(anchor.y, point.y), width: abs(point.x - anchor.x), height: abs(point.y - anchor.y))
        }
        updateButtons()
        needsDisplay = true
    }
    private func updateButtons() {
        confirm.isHidden = selection.width < 8 || selection.height < 8
        let y = selection.minY >= 48 ? selection.minY - 42 : min(bounds.height - 40, selection.maxY + 8)
        let x = min(max(selection.midX - 112, 8), bounds.width - 232)
        confirm.frame = CGRect(x: x, y: y, width: 120, height: 32)
        cancel.frame = CGRect(x: x + 124, y: y, width: 100, height: 32)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dismiss() }
        else if event.keyCode == 36 || event.keyCode == 49 || event.keyCode == 76 { submit() }
    }
    @objc private func submit() {
        guard selection.width >= 8, selection.height >= 8 else { return }
        onConfirm?(selection)
    }
    @objc private func dismiss() { onCancel?() }
}

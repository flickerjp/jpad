import SwiftUI
import UIKit

struct HardwareKeyboardPadInputView: UIViewRepresentable {
    let isEnabled: Bool
    let onKeyPressChange: (String, Bool) -> Void

    func makeUIView(context: Context) -> HardwareKeyboardPadInputCaptureView {
        let view = HardwareKeyboardPadInputCaptureView()
        view.onKeyPressChange = onKeyPressChange
        view.isCaptureEnabled = isEnabled
        return view
    }

    func updateUIView(_ uiView: HardwareKeyboardPadInputCaptureView, context: Context) {
        uiView.onKeyPressChange = onKeyPressChange
        uiView.isCaptureEnabled = isEnabled
        uiView.refreshFirstResponder()
    }
}

final class HardwareKeyboardPadInputCaptureView: UIView {
    var onKeyPressChange: ((String, Bool) -> Void)?
    var isCaptureEnabled = false {
        didSet {
            guard oldValue != isCaptureEnabled else { return }
            pressedKeys.removeAll()
        }
    }

    private var pressedKeys: Set<String> = []

    override var canBecomeFirstResponder: Bool {
        isCaptureEnabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshFirstResponder()
    }

    func refreshFirstResponder() {
        guard window != nil else { return }
        if isCaptureEnabled {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.isFirstResponder {
                    _ = self.becomeFirstResponder()
                }
            }
        } else if isFirstResponder {
            _ = resignFirstResponder()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = normalizedKey(from: press), pressedKeys.insert(key).inserted else { continue }
            onKeyPressChange?(key, true)
            handled = true
        }
        if handled {
            return
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = normalizedKey(from: press), pressedKeys.remove(key) != nil else { continue }
            onKeyPressChange?(key, false)
            handled = true
        }
        if handled {
            return
        }
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = normalizedKey(from: press), pressedKeys.remove(key) != nil else { continue }
            onKeyPressChange?(key, false)
            handled = true
        }
        if handled {
            return
        }
        super.pressesCancelled(presses, with: event)
    }

    private func normalizedKey(from press: UIPress) -> String? {
        guard let key = press.key else { return nil }
        let blockedModifiers = key.modifierFlags.intersection([.command, .alternate, .control])
        guard blockedModifiers.isEmpty else { return nil }
        let text = key.charactersIgnoringModifiers.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return text.isEmpty ? nil : text
    }
}

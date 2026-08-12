import UIKit

/// Single responsibility: present UIKit alerts/confirmations on top of
/// the current window. This is the only place in the feature that
/// touches `UIApplication` / `UIAlertController`.
final class AlertPresenter: AlertPresenting {

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert)
    }

    func showConfirmation(
        title: String,
        message: String,
        confirmTitle: String,
        isDestructive: Bool,
        onConfirm: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: isDestructive ? .destructive : .default) { _ in
            onConfirm()
        })
        present(alert)
    }

    private func present(_ alert: UIAlertController) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
}
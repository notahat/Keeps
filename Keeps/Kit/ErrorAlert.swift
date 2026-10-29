import SwiftUI

extension View {
    /// Shows an alert with an OK button and the error's description whenever
    /// `error` is non-nil. Calls `onDismiss` when the user dismisses it, so
    /// the caller can clear the error wherever it's kept.
    func errorAlert(
        _ title: LocalizedStringKey,
        error: Error?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: Binding(
            get: { error != nil },
            set: { isPresented in
                if !isPresented {
                    onDismiss()
                }
            }
        )) {
            Button("OK") {}
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }
}

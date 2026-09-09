import SwiftUI

struct UsageView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("How to use macslator")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(
                        icon: "keyboard",
                        title: "Translate",
                        content: "Type or paste text in the left panel. macslator waits 1 second after you stop typing, then translates automatically. The result appears in the right panel."
                    )

                    section(
                        icon: "arrow.left.arrow.right",
                        title: "Swap languages",
                        content: "Use the swap button between the language pills to invert the translation direction. Your last chosen pair is remembered for next time."
                    )

                    section(
                        icon: "apple.logo",
                        title: "Apple Translation",
                        content: "The default mode uses Apple's native Translation framework. It works offline and supports many languages."
                    )

                    section(
                        icon: "cpu",
                        title: "Local LLM",
                        content: "Enable the LLM toggle in the bottom-right corner. If you have already selected a model in Settings, it loads automatically. The LLM gives better results for full sentences."
                    )

                    section(
                        icon: "arrow.down.right.and.arrow.up.left",
                        title: "Collapse",
                        content: "Tap the app icon in the top-left corner to collapse macslator into a small floating icon. The icon shows a colored arrow badge. Tap it again to expand back to the full translator."
                    )

                    section(
                        icon: "doc.text.magnifyingglass",
                        title: "Logs",
                        content: "If a translation fails, open the log viewer from the toolbar to see the exact error code and details. This helps diagnose model or configuration issues."
                    )

                    section(
                        icon: "gearshape",
                        title: "Settings",
                        content: "In Settings you can choose a local MLX model from Hugging Face, adjust max output tokens, and manage the model cache."
                    )
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480, height: 520)
    }

    private func section(icon: String, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(content)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

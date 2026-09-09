import SwiftUI

struct AboutView: View {
    @Binding var isPresented: Bool
    @State private var showingUsage = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                if let icon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                }

                Text("macslator")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

                Text("Offline translator for macOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Developed by")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("github.com/zalomea", destination: URL(string: "https://github.com/zalomea")!)
                    .font(.callout)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Credits")
                    .font(.headline)

                Text("Apple Translation powered by the native Translation framework.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Local LLM inference powered by MLX Swift.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("How to use") {
                    showingUsage = true
                }

                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320, height: 420)
        .sheet(isPresented: $showingUsage) {
            UsageView(isPresented: $showingUsage)
        }
    }
}

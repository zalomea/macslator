import SwiftUI

struct LogView: View {
    @StateObject private var logger = Logger.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if logger.entries.isEmpty {
                        Text("No log entries yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(logger.entries.reversed(), id: \.self) { entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Button("Clear") {
                    logger.clear()
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 680, height: 420)
    }
}

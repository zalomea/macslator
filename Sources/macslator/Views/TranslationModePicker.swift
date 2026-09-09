import SwiftUI

struct TranslationModePicker: View {
    @Binding var mode: TranslationMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TranslationMode.allCases) { mode in
                Button(action: { self.mode = mode }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(mode == self.mode ? Color.accentColor : Color.clear)
                .foregroundStyle(mode == self.mode ? Color.white : Color.primary)
                .clipShape(Capsule())
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
        .fixedSize()
    }
}

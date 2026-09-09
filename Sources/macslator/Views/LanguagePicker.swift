import SwiftUI

struct LanguagePicker: View {
    @Binding var selection: Language
    let label: String
    let availableLanguages: [Language]

    var body: some View {
        Menu {
            ForEach(availableLanguages) { language in
                Button(action: { selection = language }) {
                    HStack {
                        Text("\(language.flag) \(language.displayName)")
                        if language == selection {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selection.flag)
                Text(selection.displayName)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

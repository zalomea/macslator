import Foundation
import Translation

enum TranslationMode: String, Codable, CaseIterable, Identifiable {
    case native = "native"
    case llm = "llm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .native: return "Apple Translation"
        case .llm: return "Local LLM"
        }
    }

    var icon: String {
        switch self {
        case .native: return "apple.logo"
        case .llm: return "cpu"
        }
    }
}

struct NativeTranslationRequest: Equatable {
    let id = UUID()
    let text: String
    let source: Language
    let target: Language
}

@available(macOS 15.0, *)
enum NativeTranslationService {
    static func localeLanguage(for language: Language) -> Locale.Language {
        Locale.Language(identifier: language.rawValue)
    }
}

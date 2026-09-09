import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    // MARK: Languages
    @AppStorage("sourceLanguage") var sourceLanguageRaw: String = Language.spanish.rawValue
    @AppStorage("targetLanguage") var targetLanguageRaw: String = Language.english.rawValue

    var sourceLanguage: Language {
        get { Language(rawValue: sourceLanguageRaw) ?? .spanish }
        set { sourceLanguageRaw = newValue.rawValue }
    }

    var targetLanguage: Language {
        get { Language(rawValue: targetLanguageRaw) ?? .english }
        set { targetLanguageRaw = newValue.rawValue }
    }

    var translationMode: TranslationMode {
        get { TranslationMode(rawValue: translationModeRaw) ?? .native }
        set { translationModeRaw = newValue.rawValue }
    }

    // MARK: Local MLX LLM
    @AppStorage("translationMode") var translationModeRaw: String = TranslationMode.native.rawValue
    @AppStorage("mlxModelID") var mlxModelID: String = "mlx-community/Llama-3.2-1B-Instruct-4bit"
    @AppStorage("llmMaxTokens") var llmMaxTokens: Int = 128

    private init() {}

    var hasLocalModel: Bool {
        !mlxModelID.isEmpty
    }
}

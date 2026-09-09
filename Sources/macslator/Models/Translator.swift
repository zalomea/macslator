import Foundation
import SwiftUI

@MainActor
final class Translator: ObservableObject {
    static let shared = Translator()

    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var sourceLanguage: Language {
        didSet { settings.sourceLanguage = sourceLanguage }
    }
    @Published var targetLanguage: Language {
        didSet { settings.targetLanguage = targetLanguage }
    }
    @Published var isTranslatingWithLLM: Bool = false
    @Published var isTranslatingWithNative: Bool = false
    @Published var errorMessage: String? = nil
    @Published var pendingNativeRequest: NativeTranslationRequest? = nil

    private let llm = MLXLLMService.shared
    private let settings = SettingsStore.shared
    private let logger = Logger.shared
    private var debounceTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?

    private init() {
        sourceLanguage = settings.sourceLanguage
        targetLanguage = settings.targetLanguage
    }

    func scheduleTranslation() {
        debounceTask?.cancel()
        translationTask?.cancel()
        isTranslatingWithLLM = false
        isTranslatingWithNative = false
        errorMessage = nil

        guard !sourceText.isEmpty else {
            translatedText = ""
            return
        }

        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                // Task was cancelled because the user typed again.
                return
            }

            guard let self = self, !Task.isCancelled else { return }
            await self.performTranslation()
        }
    }

    private func performTranslation() async {
        let settings = SettingsStore.shared
        let mode = settings.translationMode

        switch mode {
        case .native:
            guard #available(macOS 15.0, *) else {
                await MainActor.run {
                    translatedText = ""
                    errorMessage = "Apple Translation requires macOS 15 or later."
                }
                return
            }
            await MainActor.run {
                isTranslatingWithNative = true
                errorMessage = nil
            }
            logger.log("Requesting native translation: '\(sourceText)' \(sourceLanguage.displayName) → \(targetLanguage.displayName)")
            await MainActor.run {
                pendingNativeRequest = NativeTranslationRequest(text: sourceText, source: sourceLanguage, target: targetLanguage)
            }

        case .llm:
            guard llm.isReady else {
                await MainActor.run {
                    translatedText = ""
                    errorMessage = "Local LLM is not loaded. Go to Settings to load a model, or switch translation mode."
                }
                logger.log("LLM selected but not ready")
                return
            }
            await MainActor.run {
                isTranslatingWithLLM = true
                errorMessage = nil
            }
            logger.log("Translating with LLM: '\(sourceText)' \(sourceLanguage.displayName) → \(targetLanguage.displayName)")

            translationTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try await llm.translate(
                        text: self.sourceText,
                        from: self.sourceLanguage,
                        to: self.targetLanguage,
                        maxTokens: settings.llmMaxTokens
                    )
                    await MainActor.run {
                        if !Task.isCancelled {
                            self.translatedText = result
                            self.isTranslatingWithLLM = false
                            self.logger.log("LLM translation result: '\(result)'")
                        }
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        self.isTranslatingWithLLM = false
                        self.logger.log("LLM translation cancelled")
                    }
                } catch {
                    await MainActor.run {
                        if !Task.isCancelled {
                            self.errorMessage = "LLM error: \(error)"
                            self.isTranslatingWithLLM = false
                            self.logger.log("LLM translation failed: \(error)")
                        }
                    }
                }
            }
        }
    }

    func translate() {
        scheduleTranslation()
    }

    func swapLanguages() {
        let tempLanguage = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = tempLanguage

        settings.sourceLanguage = sourceLanguage
        settings.targetLanguage = targetLanguage

        let tempText = sourceText
        sourceText = translatedText
        translatedText = tempText
    }

    func setLanguagePair(source: Language, target: Language) {
        sourceLanguage = source
        targetLanguage = target
        settings.sourceLanguage = source
        settings.targetLanguage = target
        scheduleTranslation()
    }

    func clear() {
        debounceTask?.cancel()
        translationTask?.cancel()
        pendingNativeRequest = nil
        isTranslatingWithLLM = false
        isTranslatingWithNative = false
        sourceText = ""
        translatedText = ""
        errorMessage = nil
    }

    func cancelPendingWork() {
        debounceTask?.cancel()
        translationTask?.cancel()
        pendingNativeRequest = nil
        isTranslatingWithLLM = false
        isTranslatingWithNative = false
        logger.log("Translator cancelled pending work")
    }
}

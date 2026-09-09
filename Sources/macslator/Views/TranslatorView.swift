import SwiftUI
@preconcurrency import Translation

@MainActor
struct TranslatorView: View {
    @StateObject private var translator = Translator.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var llm = MLXLLMService.shared
    @StateObject private var appState = AppState.shared
    @State private var showingSettings = false
    @State private var showingLogs = false
    @State private var nativeConfig: TranslationSession.Configuration?

    var body: some View {
        Group {
            if appState.isCollapsed {
                collapsedView
            } else {
                expandedView
            }
        }
    }

    // MARK: - Collapsed View

    private var collapsedView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)

            Button(action: expandFromIcon) {
                ZStack {
                    if let icon = NSApplication.shared.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .cornerRadius(10)
                    }

                    // Expand indicator
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 18, y: -18)
                }
            }
            .buttonStyle(.plain)
            .help("Expand macslator")
        }
        .frame(width: 80, height: 80)
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 400, idealHeight: 480)
        .onChange(of: translator.sourceText) { _, _ in
            translator.translate()
        }
        .onChange(of: translator.sourceLanguage) { _, _ in
            translator.cancelPendingWork()
            translator.translate()
        }
        .onChange(of: translator.targetLanguage) { _, _ in
            translator.cancelPendingWork()
            translator.translate()
        }
        .onChange(of: settings.translationMode) { _, newMode in
            translator.cancelPendingWork()
            if newMode == .llm && llm.isReady == false && settings.hasLocalModel && !llm.isLoading {
                loadModel()
            }
            translator.translate()
        }
        .onChange(of: translator.pendingNativeRequest) { _, request in
            guard let request = request else { return }
            if #available(macOS 15.0, *) {
                Logger.shared.log("Native request changed: \(request.source.displayName) → \(request.target.displayName)")
                let source = NativeTranslationService.localeLanguage(for: request.source)
                let target = NativeTranslationService.localeLanguage(for: request.target)

                if nativeConfig?.source == source && nativeConfig?.target == target {
                    // Same language pair: invalidate to re-run with new content.
                    Logger.shared.log("Invalidating existing native configuration")
                    nativeConfig?.invalidate()
                } else {
                    // Different language pair: create a new configuration.
                    Logger.shared.log("Creating new native translation configuration")
                    nativeConfig = TranslationSession.Configuration(source: source, target: target)
                }
            }
        }
        .translationTask(nativeConfig) { @MainActor session in
            Logger.shared.log("Native translation task triggered")
            guard let request = translator.pendingNativeRequest else {
                Logger.shared.log("Native translation task skipped: no pending request")
                return
            }
            do {
                let response = try await session.translate(request.text)
                let result = response.targetText
                // Only accept the result if native mode is still active.
                if settings.translationMode == .native {
                    translator.translatedText = result
                    Logger.shared.log("Native translation result: '\(result)'")
                } else {
                    Logger.shared.log("Native translation result ignored: mode changed")
                }
                translator.isTranslatingWithNative = false
            } catch is CancellationError {
                translator.isTranslatingWithNative = false
                Logger.shared.log("Native translation cancelled")
            } catch {
                translator.errorMessage = "Apple Translation error: \(error.localizedDescription)"
                translator.isTranslatingWithNative = false
                Logger.shared.log("Native translation failed: \(error)")
            }
            translator.pendingNativeRequest = nil
        }
        .onAppear {
            autoLoadLLMIfNeeded()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
        }
        .sheet(isPresented: $appState.showAbout) {
            AboutView(isPresented: $appState.showAbout)
        }
        .sheet(isPresented: $showingLogs) {
            LogView(isPresented: $showingLogs)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { appState.toggleCollapse() }) {
                HStack(spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        if let icon = NSApplication.shared.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                                .cornerRadius(6)
                        }

                        // Collapse indicator
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 12, height: 12)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }

                    Text("macslator")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .help("Collapse macslator")

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showingLogs.toggle() }) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("View logs")

                Button(action: { appState.showHelp() }) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("About macslator")

                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var content: some View {
        VStack(spacing: 16) {
            languageBar
            HStack(spacing: 16) {
                sourceArea
                targetArea
            }
            statusBar
        }
        .padding(16)
    }

    private var languageBar: some View {
        HStack(spacing: 12) {
            LanguagePicker(
                selection: $translator.sourceLanguage,
                label: "Source",
                availableLanguages: availableLanguages
            )

            Button(action: { translator.swapLanguages() }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Swap languages")

            LanguagePicker(
                selection: $translator.targetLanguage,
                label: "Target",
                availableLanguages: availableLanguages
            )

            Spacer()

            Button(action: translator.clear) {
                Text("Clear")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }

    private var availableLanguages: [Language] {
        switch settings.translationMode {
        case .native:
            return Language.nativeSupportedLanguages
        case .llm:
            return Language.allCases
        }
    }

    private var sourceArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Original")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: pasteIntoSource) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Paste from clipboard")
            }

            TextEditor(text: $translator.sourceText)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private var targetArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Translation")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: copyTranslation) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(translator.translatedText.isEmpty)
                .help("Copy translation")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: .constant(translator.translatedText))
                    .font(.body)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                if translator.isTranslatingWithLLM || translator.isTranslatingWithNative {
                    ProgressView()
                        .controlSize(.small)
                        .padding(10)
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            if let error = translator.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                statusLabel
            }

            Spacer()

            HStack(spacing: 8) {
                if settings.translationMode == .llm && llm.isLoading {
                    ProgressView()
                        .controlSize(.small)

                    Button("Cancel") {
                        llm.cancelLoad()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }

                TranslationModePicker(mode: $settings.translationMode)
            }
        }
    }

    private var statusLabel: some View {
        Group {
            switch settings.translationMode {
            case .native:
                Label("Apple Translation", systemImage: "apple.logo")
                    .foregroundStyle(.blue)
            case .llm:
                if llm.isReady {
                    Label("Local LLM active", systemImage: "cpu")
                        .foregroundStyle(.green)
                } else {
                    Label("Local LLM not ready", systemImage: "cpu")
                        .foregroundStyle(.orange)
                }
            }
        }
        .font(.caption)
    }

    private func loadModel() {
        Task {
            do {
                try await llm.load(modelID: settings.mlxModelID)
            } catch {
                Logger.shared.log("Failed to load MLX LLM: \(error)")
            }
        }
    }

    private func autoLoadLLMIfNeeded() {
        guard settings.translationMode == .llm,
              settings.hasLocalModel,
              !llm.isReady,
              !llm.isLoading else { return }
        Logger.shared.log("Auto-loading MLX LLM on launch")
        loadModel()
    }

    private func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translator.translatedText, forType: .string)
    }

    private func pasteIntoSource() {
        guard let pasted = NSPasteboard.general.string(forType: .string), !pasted.isEmpty else { return }
        translator.sourceText = pasted
    }

    private func expandFromIcon() {
        appState.toggleCollapse()
        pasteIntoSource()
        translator.translate()
    }
}

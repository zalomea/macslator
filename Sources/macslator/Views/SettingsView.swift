import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var llm = MLXLLMService.shared
    @StateObject private var hf = HuggingFaceAPIService.shared
    @State private var searchTerm: String = ""
    @State private var showingSearchResults = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    llmSection
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
        .frame(width: 600, height: 680)
    }

    // MARK: - Local MLX LLM Section

    private var llmSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    Text("Local MLX LLM")
                        .font(.headline)

                    Spacer()
                }

                Text("A local MLX model improves translation quality for full sentences. Models are downloaded from Hugging Face and cached locally.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Status:")
                        .font(.callout)
                    Text(llm.statusMessage)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(statusColor)
                    Spacer()
                }

                if llm.isLoading {
                    ProgressView(value: llm.downloadProgress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("Downloaded \(Int(llm.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") {
                            llm.cancelLoad()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Hugging Face model ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("mlx-community/Model-Name-4bit", text: $settings.mlxModelID)
                            .textFieldStyle(.roundedBorder)

                        Button("Search") {
                            showingSearchResults = true
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("Load / Download") {
                        loadModel()
                    }
                    .disabled(settings.mlxModelID.isEmpty || llm.isLoading)

                    Button("Unload") {
                        settings.translationMode = .native
                        llm.unload()
                    }
                    .buttonStyle(.borderless)
                    .disabled(!llm.isReady && !llm.isLoading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max output tokens: \(settings.llmMaxTokens)")
                        .font(.caption)
                    Slider(value: .init(
                        get: { Double(settings.llmMaxTokens) },
                        set: { settings.llmMaxTokens = Int($0) }
                    ), in: 32...1024, step: 32)
                }

                Text("Recommended: mlx-community/Llama-3.2-1B-Instruct-4bit, mlx-community/Qwen3-1.7B-4bit, mlx-community/Phi-4-mini-instruct-4bit")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                cacheSection
            }
            .padding(12)
        }
        .sheet(isPresented: $showingSearchResults) {
            HuggingFaceSearchView(isPresented: $showingSearchResults, searchTerm: $searchTerm)
        }
    }

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hugging Face cache")
                    .font(.callout.weight(.medium))
                Spacer()
                Text(cacheSizeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

                Text("Downloaded models are stored in ~/.cache/huggingface/hub and reused across launches. They are not deleted automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)

                if !cachedModels.isEmpty {
                    Text("Cached models")
                        .font(.callout.weight(.medium))
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(cachedModels, id: \.self) { modelID in
                            HStack {
                                Text(modelID)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Button("Use") {
                                    settings.mlxModelID = modelID
                                }
                                .controlSize(.small)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                }

            Button("Clear model cache") {
                clearCache()
            }
            .disabled(cacheSize == 0)
        }
        .padding(.top, 8)
        .onAppear {
            updateCacheInfo()
        }
    }

    @State private var cacheSize: Int64 = 0
    @State private var cachedModels: [String] = []

    private var cacheSizeString: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    private func updateCacheInfo() {
        cacheSize = MLXLLMService.cacheSize()
        cachedModels = MLXLLMService.cachedModels()
    }

    private func clearCache() {
        do {
            try MLXLLMService.clearCache()
            updateCacheInfo()
            // If a model is currently loaded, unload it because its files are gone.
            if llm.isReady || llm.isLoading {
                llm.unload()
            }
        } catch {
            Logger.shared.log("Failed to clear Hugging Face cache: \(error)")
        }
    }

    private var statusColor: Color {
        if llm.isReady { return .green }
        if llm.isLoading { return .orange }
        return .secondary
    }

    private func loadModel() {
        Task {
            do {
                try await llm.load(modelID: settings.mlxModelID)
            } catch {
                Logger.shared.log("Failed to load MLX model: \(error)")
            }
        }
    }

}

struct HuggingFaceSearchView: View {
    @Binding var isPresented: Bool
    @Binding var searchTerm: String
    @StateObject private var hf = HuggingFaceAPIService.shared
    @StateObject private var settings = SettingsStore.shared
    @State private var query: String = ""
    @State private var minGB: Double = 0
    @State private var maxGB: Double = 10

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Search Hugging Face Models")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Search term (e.g. llama, qwen, phi)", text: $query)
                        .textFieldStyle(.roundedBorder)

                    Button("Search") {
                        Task {
                            await hf.search(term: query, tag: "mlx", limit: 50, minGB: minGB, maxGB: maxGB == 10 ? .infinity : maxGB)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(query.isEmpty || hf.isLoading)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Size filter: \(String(format: "%.1f", minGB)) GB – \(maxGB >= 10 ? "∞" : String(format: "%.1f", maxGB)) GB")
                            .font(.caption)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Min GB")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Slider(value: $minGB, in: 0...10, step: 0.5)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max GB")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Slider(value: $maxGB, in: 0.5...10, step: 0.5)
                        }
                    }
                }

                if hf.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if let error = hf.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                List(hf.filteredModels) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.callout.weight(.medium))
                            HStack(spacing: 8) {
                                Text(model.sizeDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                if let downloads = model.downloads {
                                    Label("\(downloads)", systemImage: "arrow.down.circle")
                                        .font(.caption2)
                                }
                                if let likes = model.likes {
                                    Label("\(likes)", systemImage: "heart")
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Select") {
                            settings.mlxModelID = model.modelId
                            searchTerm = model.modelId
                            isPresented = false
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .padding(16)

            Divider()

            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
            }
            .padding(16)
        }
        .frame(width: 600, height: 560)
        .onAppear {
            query = searchTerm
            if !query.isEmpty {
                Task {
                    await hf.search(term: query, tag: "mlx", limit: 50, minGB: minGB, maxGB: maxGB == 10 ? .infinity : maxGB)
                }
            }
        }
    }
}

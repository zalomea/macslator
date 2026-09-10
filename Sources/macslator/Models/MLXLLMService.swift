import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

enum MLXLLMError: Error, CustomStringConvertible {
    case noModelLoaded
    case modelLoadFailed(String)
    case generationFailed(String)

    var description: String {
        switch self {
        case .noModelLoaded: return "No MLX model loaded"
        case .modelLoadFailed(let reason): return "Failed to load model: \(reason)"
        case .generationFailed(let reason): return "Generation failed: \(reason)"
        }
    }
}

@MainActor
final class MLXLLMService: ObservableObject {
    static let shared = MLXLLMService()

    @Published var isLoading: Bool = false
    @Published var isReady: Bool = false
    @Published var statusMessage: String = "No model loaded"
    @Published var downloadProgress: Double = 0

    private var modelContainer: ModelContainer?
    private var loadedModelID: String?
    private var loadTask: Task<ModelContainer, Error>?

    init() {}

    func load(modelID: String) async throws {
        // Cancel any in-flight load.
        loadTask?.cancel()
        loadTask = nil

        await MainActor.run {
            isLoading = true
            isReady = false
            statusMessage = "Loading \(modelID)…"
            downloadProgress = 0
        }

        let configuration = ModelConfiguration(id: modelID)

        let task = Task { [weak self] () -> ModelContainer in
            guard let self = self else { throw MLXLLMError.noModelLoaded }

            let container: ModelContainer

            // If the model snapshot is already cached locally, load from disk without any network request.
            if let snapshotDirectory = self.cachedSnapshotDirectory(for: modelID) {
                Logger.shared.log("Loading \(modelID) from local cache: \(snapshotDirectory.path)")
                await MainActor.run {
                    self.statusMessage = "Loading \(modelID) from cache…"
                }
                container = try await loadModelContainer(
                    from: snapshotDirectory,
                    using: #huggingFaceTokenizerLoader()
                )
            } else {
                Logger.shared.log("Downloading \(modelID) from Hugging Face…")
                container = try await loadModelContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: configuration
                ) { [weak self] progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = fraction
                        if fraction > 0 && fraction < 1 {
                            self?.statusMessage = "Downloading \(modelID)… \(Int(fraction * 100))%"
                        }
                    }
                }
            }

            return container
        }

        loadTask = task

        do {
            let container = try await task.value
            loadTask = nil
            await MainActor.run {
                self.modelContainer = container
                self.loadedModelID = modelID
                self.isLoading = false
                self.isReady = true
                self.statusMessage = "\(modelID) ready"
            }
        } catch is CancellationError {
            loadTask = nil
            await MainActor.run {
                self.isLoading = false
                self.statusMessage = "Download cancelled"
                self.downloadProgress = 0
            }
            throw CancellationError()
        } catch {
            loadTask = nil
            await MainActor.run {
                self.isLoading = false
                self.statusMessage = "Failed to load \(modelID)"
                self.downloadProgress = 0
            }
            throw error
        }
    }

    func cancelLoad() {
        Logger.shared.log("Cancelling model load")
        loadTask?.cancel()
    }

    func unload() {
        loadTask?.cancel()
        loadTask = nil
        modelContainer = nil
        loadedModelID = nil
        isLoading = false
        isReady = false
        statusMessage = "No model loaded"
        downloadProgress = 0
    }

    func translate(text: String, from source: Language, to target: Language, maxTokens: Int = 128) async throws -> String {
        guard let container = modelContainer else {
            throw MLXLLMError.noModelLoaded
        }

        let prompt = translationPrompt(text: text, from: source, to: target)
        let userInput = UserInput(prompt: prompt)

        let lmInput = try await container.prepare(input: userInput)
        let params = GenerateParameters(maxTokens: maxTokens, temperature: 0.1)
        let stream = try await container.generate(input: lmInput, parameters: params)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
            if case .chunk(let piece) = event {
                output += piece
            }
        }

        return cleanTranslation(output)
    }

    func translationPrompt(text: String, from source: Language, to target: Language) -> String {
        """
        Translate from \(source.displayName) to \(target.displayName). Reply with only the translation.

        \(source.displayName): \(text)
        \(target.displayName):
        """
    }

    func cleanTranslation(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stopMarkers = ["Input:", "Translation:", "Rules:", "Provide ONLY"]
        for marker in stopMarkers {
            if let range = cleaned.range(of: marker) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cachedSnapshotDirectory(for modelID: String) -> URL? {
        let fileManager = FileManager.default
        let cacheDir = MLXLLMService.cacheDirectoryURL()

        let sanitized = modelID.replacingOccurrences(of: "/", with: "--")
        let repoDir = cacheDir.appendingPathComponent("models--\(sanitized)", isDirectory: true)

        guard fileManager.fileExists(atPath: repoDir.path) else {
            return nil
        }

        // Find any available ref (main, master, or other branch/tag).
        let refsDir = repoDir.appendingPathComponent("refs", isDirectory: true)
        guard let refFiles = try? fileManager.contentsOfDirectory(atPath: refsDir.path),
              let refName = refFiles.first(where: { !$0.hasPrefix(".") }) else {
            return nil
        }

        let refFile = refsDir.appendingPathComponent(refName)
        guard let commitHash = try? String(contentsOf: refFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !commitHash.isEmpty else {
            return nil
        }

        let snapshotDir = repoDir.appendingPathComponent("snapshots/\(commitHash)", isDirectory: true)
        guard fileManager.fileExists(atPath: snapshotDir.path) else {
            return nil
        }

        // Verify at least one weights file exists (recursively, in case of sharded models).
        guard hasWeights(in: snapshotDir) else {
            return nil
        }

        return snapshotDir
    }

    func hasWeights(in directory: URL) -> Bool {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return false
        }

        let weightExtensions = [".safetensors", ".bin", ".weights", ".gguf", ".ckpt", ".pt"]
        for case let fileURL as URL in enumerator {
            let lower = fileURL.lastPathComponent.lowercased()
            if weightExtensions.contains(where: { lower.hasSuffix($0) }) {
                return true
            }
        }
        return false
    }

    // MARK: - Cache management

    static func cacheDirectoryURL() -> URL {
        let fileManager = FileManager.default

        if let hubCache = ProcessInfo.processInfo.environment["HF_HUB_CACHE"], !hubCache.isEmpty {
            return URL(fileURLWithPath: hubCache, isDirectory: true)
        }

        if let hfHome = ProcessInfo.processInfo.environment["HF_HOME"], !hfHome.isEmpty {
            return URL(fileURLWithPath: hfHome, isDirectory: true).appendingPathComponent("hub", isDirectory: true)
        }

        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/huggingface/hub", isDirectory: true)
    }

    static func cachedModels() -> [String] {
        let directory = cacheDirectoryURL()
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        return contents
            .filter { $0.hasPrefix("models--") }
            .compactMap { name -> String? in
                // models--org--repo-name -> org/repo-name
                var parts = name.dropFirst(8).split(separator: "--", omittingEmptySubsequences: false)
                guard parts.count >= 2 else { return nil }
                let org = parts.removeFirst()
                let repo = parts.joined(separator: "-")
                let modelID = "\(org)/\(repo)"

                // Only list models that have a loadable snapshot.
                let service = MLXLLMService()
                guard service.cachedSnapshotDirectory(for: modelID) != nil else { return nil }
                return modelID
            }
            .sorted()
    }

    static func cacheSize() -> Int64 {
        let directory = cacheDirectoryURL()
        return directorySize(directory)
    }

    static func clearCache() throws {
        let directory = cacheDirectoryURL()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                total += Int64(values.fileSize ?? 0)
            } catch {
                continue
            }
        }
        return total
    }
}

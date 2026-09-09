import Foundation

struct HuggingFaceModel: Identifiable, Codable, Equatable {
    let id: String
    let modelId: String
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    var sizeBytes: Int64?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case modelId = "id"
        case downloads
        case likes
        case tags
    }

    var displayName: String { modelId }

    var sizeGB: Double? {
        guard let bytes = sizeBytes else { return nil }
        return Double(bytes) / 1_073_741_824.0
    }

    var sizeDescription: String {
        guard let gb = sizeGB else { return "Unknown size" }
        return String(format: "%.2f GB", gb)
    }
}

@MainActor
final class HuggingFaceAPIService: ObservableObject {
    static let shared = HuggingFaceAPIService()

    @Published var models: [HuggingFaceModel] = []
    @Published var filteredModels: [HuggingFaceModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var minGBFilter: Double = 0
    private var maxGBFilter: Double = .infinity

    private init() {}

    func search(term: String, tag: String = "mlx", limit: Int = 20, minGB: Double = 0, maxGB: Double = .infinity) async {
        isLoading = true
        errorMessage = nil
        models = []
        filteredModels = []
        minGBFilter = minGB
        maxGBFilter = maxGB

        let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://huggingface.co/api/models?search=\(encodedTerm)&filter=\(encodedTag)&sort=downloads&direction=-1&limit=\(limit)"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid search URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            var decoded = try JSONDecoder().decode([HuggingFaceModel].self, from: data)

            // Fetch sizes concurrently.
            await withTaskGroup(of: (Int, Int64?).self) { group in
                for (index, model) in decoded.enumerated() {
                    group.addTask {
                        let size = await self.fetchModelSize(modelId: model.modelId)
                        return (index, size)
                    }
                }
                for await (index, size) in group {
                    decoded[index].sizeBytes = size
                }
            }

            models = decoded
            applySizeFilter(minGB: minGB, maxGB: maxGB)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            Logger.shared.log("Hugging Face search failed: \(error)")
        }

        isLoading = false
    }

    func applySizeFilter(minGB: Double, maxGB: Double) {
        minGBFilter = minGB
        maxGBFilter = maxGB
        filteredModels = models.filter { model in
            guard let gb = model.sizeGB else { return true }
            return gb >= minGB && gb <= maxGB
        }
    }

    private nonisolated func fetchModelSize(modelId: String) async -> Int64? {
        let encodedModelId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelId
        let urlString = "https://huggingface.co/api/models/\(encodedModelId)/treesize/main/"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(TreeSizeResponse.self, from: data)
            return Int64(decoded.size)
        } catch {
            Logger.shared.log("Failed to fetch size for \(modelId): \(error)")
            return nil
        }
    }
}

private struct TreeSizeResponse: Codable {
    let path: String
    let size: Int
}

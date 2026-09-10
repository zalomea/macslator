import XCTest
@testable import macslator

final class HuggingFaceModelTests: XCTestCase {

    func testDecodesFromHuggingFaceSearchResponse() throws {
        let json = """
        [
          {
            "_id": "org/model-a",
            "id": "org/model-a",
            "downloads": 1234,
            "likes": 42,
            "tags": ["mlx", "text-generation"]
          }
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([HuggingFaceModel].self, from: json)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].modelId, "org/model-a")
        XCTAssertEqual(decoded[0].downloads, 1234)
        XCTAssertEqual(decoded[0].likes, 42)
        XCTAssertEqual(decoded[0].tags, ["mlx", "text-generation"])
    }

    func testSizeGBWhenNoBytesIsNil() {
        let model = HuggingFaceModel(id: "org/a", modelId: "org/a", downloads: 1, likes: 1, tags: [], sizeBytes: nil)
        XCTAssertNil(model.sizeGB)
        XCTAssertEqual(model.sizeDescription, "Unknown size")
    }

    func testSizeGBComputesFromBytes() {
        let bytes: Int64 = 1_073_741_824
        let model = HuggingFaceModel(id: "org/a", modelId: "org/a", downloads: 1, likes: 1, tags: [], sizeBytes: bytes)
        XCTAssertEqual(model.sizeGB, 1.0)
        XCTAssertEqual(model.sizeDescription, "1.00 GB")
    }

    func testDisplayNameUsesModelId() {
        let model = HuggingFaceModel(id: "org/a", modelId: "org/a", downloads: nil, likes: nil, tags: nil, sizeBytes: nil)
        XCTAssertEqual(model.displayName, "org/a")
    }
}
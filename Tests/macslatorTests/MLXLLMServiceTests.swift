import XCTest
@testable import macslator

final class MLXLLMServiceTests: XCTestCase {

    func testTranslationPromptStructure() {
        let service = MLXLLMService()
        let prompt = service.translationPrompt(text: "hola", from: .spanish, to: .english)

        XCTAssertTrue(prompt.contains("Translate from Spanish to English"))
        XCTAssertTrue(prompt.contains("Spanish: hola"))
        XCTAssertTrue(prompt.contains("English:"))
    }

    func testCleanTranslationTrimsWhitespaceAndNewlines() {
        let service = MLXLLMService()
        XCTAssertEqual(service.cleanTranslation("  hello world  "), "hello world")
        XCTAssertEqual(service.cleanTranslation("\n\nhello\n"), "hello")
    }

    func testCleanTranslationCollapsesInternalWhitespace() {
        let service = MLXLLMService()
        XCTAssertEqual(service.cleanTranslation("hello   world\nfoo\tbar"), "hello world foo bar")
    }

    func testCleanTranslationStripsStopMarkers() {
        let service = MLXLLMService()
        XCTAssertEqual(service.cleanTranslation("Good morning.\nInput: the original text"), "Good morning.")
        XCTAssertEqual(service.cleanTranslation("Yes.\nTranslation: the rest is ignored"), "Yes.")
        XCTAssertEqual(service.cleanTranslation("Done.\nRules: ignore this"), "Done.")
    }

    func testCachedSnapshotDirectoryDetectsValidSnapshot() throws {
        let cache = FileManager.default.temporaryDirectory
            .appendingPathComponent("macslator-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: cache)
            setenv("HF_HUB_CACHE", "", 1)
            unsetenv("HF_HUB_CACHE")
        }
        try? FileManager.default.removeItem(at: cache)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)

        let modelID = "org/repo"
        let sanitized = "org--repo"
        let repoDir = cache.appendingPathComponent("models--\(sanitized)", isDirectory: true)
        let refsDir = repoDir.appendingPathComponent("refs", isDirectory: true)
        let commitHash = "abc123"
        let snapshotDir = repoDir.appendingPathComponent("snapshots/\(commitHash)", isDirectory: true)

        try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
        try "\(commitHash)\n".write(to: refsDir.appendingPathComponent("main"), atomically: true, encoding: .utf8)
        try Data([0x00, 0x01]).write(to: snapshotDir.appendingPathComponent("model.safetensors"))

        setenv("HF_HUB_CACHE", cache.path, 1)

        let service = MLXLLMService()
        XCTAssertEqual(service.cachedSnapshotDirectory(for: modelID)?.path, snapshotDir.path)
    }

    func testCachedSnapshotDirectoryReturnsNilWithoutWeights() throws {
        let cache = FileManager.default.temporaryDirectory
            .appendingPathComponent("macslator-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: cache)
            unsetenv("HF_HUB_CACHE")
        }
        try? FileManager.default.removeItem(at: cache)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)

        let repoDir = cache.appendingPathComponent("models--org--repo", isDirectory: true)
        let refsDir = repoDir.appendingPathComponent("refs", isDirectory: true)
        let snapshotDir = repoDir.appendingPathComponent("snapshots/abc123", isDirectory: true)

        try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
        try "abc123\n".write(to: refsDir.appendingPathComponent("main"), atomically: true, encoding: .utf8)
        // No weights file present.
        try "config.json".write(to: snapshotDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        setenv("HF_HUB_CACHE", cache.path, 1)

        let service = MLXLLMService()
        XCTAssertNil(service.cachedSnapshotDirectory(for: "org/repo"))
    }

    func testCachedSnapshotDirectoryReturnsNilWithoutCache() {
        unsetenv("HF_HUB_CACHE")
        let service = MLXLLMService()
        XCTAssertNil(service.cachedSnapshotDirectory(for: "org/repo"))
    }

    func testHasWeightsDetectsWeightExtensions() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("macslator-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let service = MLXLLMService()

        let weights = dir.appendingPathComponent("model.safetensors")
        try Data([0x00]).write(to: weights)
        XCTAssertTrue(service.hasWeights(in: dir))

        let sharded = dir.appendingPathComponent("nested/model-00001-of-00002.safetensors")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try Data([0x00]).write(to: sharded)
        XCTAssertTrue(service.hasWeights(in: dir))
    }
}
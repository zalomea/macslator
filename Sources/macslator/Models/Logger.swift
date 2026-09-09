import Foundation

final class Logger: ObservableObject, @unchecked Sendable {
    static let shared = Logger()

    @Published var entries: [String] = []

    private init() {}

    func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        let timestamp = formatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)"

        DispatchQueue.main.async { [weak self] in
            self?.entries.append(entry)
        }

        #if DEBUG
        print("[macslator] \(entry)")
        #endif
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
    }
}

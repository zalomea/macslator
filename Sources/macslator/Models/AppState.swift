import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showAbout: Bool = false
    @Published var isCollapsed: Bool = false

    private init() {}

    func showHelp() {
        showAbout = true
    }

    func toggleCollapse() {
        isCollapsed.toggle()
        AppDelegate.shared?.setCollapsed(isCollapsed)
    }
}

import SwiftUI
import RKNChecker

/// Точка входа нативного macOS приложения RKN Checker.
@main
struct RKNCheckerMacApp: App {
    var body: some Scene {
        WindowGroup {
            MainAdaptiveView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

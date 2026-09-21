import SwiftUI
import RKNChecker

#if os(macOS)
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
#else
/// Фолбэк для сборки под iOS/iPadOS без специфичных для macOS модификаторов окна.
@main
struct RKNCheckerMacApp: App {
    var body: some Scene {
        WindowGroup {
            MainAdaptiveView()
                .preferredColorScheme(.dark)
        }
    }
}
#endif

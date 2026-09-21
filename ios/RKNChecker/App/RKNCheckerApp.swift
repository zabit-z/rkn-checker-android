import SwiftUI

/// Главная точка входа приложения RKN Checker для iOS и iPadOS.
@main
public struct RKNCheckerApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainAdaptiveView()
                .preferredColorScheme(.dark)
        }
    }
}

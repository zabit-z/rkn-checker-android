import SwiftUI

/// Адаптивная многоколоночная сетка для iPadOS (и широких экранов).
/// Автоматически подстраивает количество столбцов от 2 до 4 в зависимости от размера экрана и ориентации.
public struct iPadGridView: View {
    public let results: [CheckResult]
    public let onSelect: (CheckResult) -> Void
    
    public init(results: [CheckResult], onSelect: @escaping (CheckResult) -> Void) {
        self.results = results
        self.onSelect = onSelect
    }
    
    // Адаптивная колонка: минимум 340pt ширины
    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 550), spacing: 14)
    ]
    
    public var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(results) { result in
                SiteResultCardView(result: result) {
                    onSelect(result)
                }
            }
        }
    }
}

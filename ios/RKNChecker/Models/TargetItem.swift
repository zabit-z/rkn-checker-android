import Foundation

/// TargetItem представляет проверяемый сетевой ресурс (домен/URL).
/// Полный аналог TargetItem из Android (MainActivity.kt).
public struct TargetItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    
    /// Человекочитаемое имя или идентификатор сервиса (например, "gosuslugi", "instagram")
    public let name: String
    
    /// Полный URL для HTTP-проверки
    public let url: String
    
    /// Флаг принадлежности к белому списку (true = Whitelist, false = Blacklist)
    public let isWhitelist: Bool
    
    public init(name: String, url: String, isWhitelist: Bool) {
        self.name = name
        self.url = url
        self.isWhitelist = isWhitelist
    }
    
    /// Извлечённый хост для DNS, TCP и TLS проверок (без схемы и путей)
    public var host: String {
        if let parsedHost = URL(string: url)?.host {
            return parsedHost
        }
        return name
    }
}

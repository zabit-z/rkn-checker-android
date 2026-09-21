import Foundation

/// Результаты многоуровневой диагностики конкретного сетевого ресурса.
/// Полный аналог CheckResult из Android.
public struct CheckResult: Identifiable, Hashable, Sendable {
    public var id: String { target.id }
    
    /// Проверяемый ресурс
    public let target: TargetItem
    
    /// Итоговый вердикт классификации
    public var verdict: Verdict
    
    /// Список диагностических примечаний (DPI сигнатуры, несовпадение DNS и т.д.)
    public var notes: [String]
    
    // DNS
    public var sysIp: String?
    public var dohIp: String?
    public var dnsMismatch: Bool
    
    // TCP (порт 443)
    public var tcpOk: Bool
    public var tcpTimeMs: Int64?
    public var tcpError: String?
    
    // TLS (рукопожатие и SNI)
    public var tlsOk: Bool
    public var tlsTimeMs: Int64?
    public var tlsError: String?
    
    // HTTP
    public var statusCode: Int?
    public var pltMs: Int64?
    public var httpError: String?
    
    public init(
        target: TargetItem,
        verdict: Verdict = .unknown,
        notes: [String] = [],
        sysIp: String? = nil,
        dohIp: String? = nil,
        dnsMismatch: Bool = false,
        tcpOk: Bool = false,
        tcpTimeMs: Int64? = nil,
        tcpError: String? = nil,
        tlsOk: Bool = false,
        tlsTimeMs: Int64? = nil,
        tlsError: String? = nil,
        statusCode: Int? = nil,
        pltMs: Int64? = nil,
        httpError: String? = nil
    ) {
        self.target = target
        self.verdict = verdict
        self.notes = notes
        self.sysIp = sysIp
        self.dohIp = dohIp
        self.dnsMismatch = dnsMismatch
        self.tcpOk = tcpOk
        self.tcpTimeMs = tcpTimeMs
        self.tcpError = tcpError
        self.tlsOk = tlsOk
        self.tlsTimeMs = tlsTimeMs
        self.tlsError = tlsError
        self.statusCode = statusCode
        self.pltMs = pltMs
        self.httpError = httpError
    }
}

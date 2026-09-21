import SwiftUI
import Combine

public enum TargetFilter: Int, CaseIterable, Identifiable, Sendable {
    case all = 0
    case whitelist = 1
    case blacklist = 2
    case blocked = 3
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .all: return "Все"
        case .whitelist: return "Whitelist"
        case .blacklist: return "Blacklist"
        case .blocked: return "Заблокировано"
        }
    }
}

/// Управляющая ViewModel приложения RKN Checker.
/// Обеспечивает координацию проверок, хранение результатов и адаптивную фильтрацию.
@MainActor
public final class CheckerViewModel: ObservableObject {
    
    // MARK: - Предустановленные списки ресурсов (1:1 соответствие Android)
    
    public let whitelistTargets: [TargetItem] = [
        TargetItem(name: "gosuslugi", url: "https://www.gosuslugi.ru/", isWhitelist: true),
        TargetItem(name: "gov.ru", url: "https://www.gov.ru/", isWhitelist: true),
        TargetItem(name: "mos.ru", url: "https://www.mos.ru/", isWhitelist: true),
        TargetItem(name: "rkn", url: "https://rkn.gov.ru/", isWhitelist: true),
        TargetItem(name: "nalog", url: "https://www.nalog.gov.ru/", isWhitelist: true),
        TargetItem(name: "yandex", url: "https://ya.ru/", isWhitelist: true),
        TargetItem(name: "yandex-maps", url: "https://yandex.ru/maps/", isWhitelist: true),
        TargetItem(name: "kinopoisk", url: "https://www.kinopoisk.ru/", isWhitelist: true),
        TargetItem(name: "sberbank", url: "https://www.sberbank.ru/", isWhitelist: true),
        TargetItem(name: "vtb", url: "https://www.vtb.ru/", isWhitelist: true),
        TargetItem(name: "alfabank", url: "https://alfabank.ru/", isWhitelist: true),
        TargetItem(name: "vk", url: "https://vk.com/", isWhitelist: true),
        TargetItem(name: "ok", url: "https://ok.ru/", isWhitelist: true),
        TargetItem(name: "ozon", url: "https://www.ozon.ru/", isWhitelist: true),
        TargetItem(name: "wildberries", url: "https://www.wildberries.ru/", isWhitelist: true),
        TargetItem(name: "avito", url: "https://www.avito.ru/", isWhitelist: true),
        TargetItem(name: "lenta", url: "https://lenta.ru/", isWhitelist: true),
        TargetItem(name: "rbc", url: "https://www.rbc.ru/", isWhitelist: true),
        TargetItem(name: "tass", url: "https://tass.ru/", isWhitelist: true),
        TargetItem(name: "rutube", url: "https://rutube.ru/", isWhitelist: true),
        TargetItem(name: "dzen", url: "https://dzen.ru/", isWhitelist: true)
    ]
    
    public let blacklistTargets: [TargetItem] = [
        TargetItem(name: "instagram", url: "https://www.instagram.com/", isWhitelist: false),
        TargetItem(name: "facebook", url: "https://www.facebook.com/", isWhitelist: false),
        TargetItem(name: "twitter/x", url: "https://x.com/", isWhitelist: false),
        TargetItem(name: "linkedin", url: "https://www.linkedin.com/", isWhitelist: false),
        TargetItem(name: "discord", url: "https://discord.com/", isWhitelist: false),
        TargetItem(name: "dailymotion", url: "https://www.dailymotion.com/", isWhitelist: false),
        TargetItem(name: "soap2day", url: "https://soap2day.day/", isWhitelist: false),
        TargetItem(name: "rutracker", url: "https://rutracker.org/", isWhitelist: false),
        TargetItem(name: "tor-project", url: "https://www.torproject.org/", isWhitelist: false),
        TargetItem(name: "protonvpn", url: "https://protonvpn.com/", isWhitelist: false),
        TargetItem(name: "deepl", url: "https://www.deepl.com/", isWhitelist: false),
        TargetItem(name: "patreon", url: "https://www.patreon.com/", isWhitelist: false),
        TargetItem(name: "bbc-russian", url: "https://www.bbc.com/russian", isWhitelist: false),
        TargetItem(name: "meduza", url: "https://meduza.io/", isWhitelist: false),
        TargetItem(name: "dw-russian", url: "https://www.dw.com/ru/", isWhitelist: false)
    ]
    
    public var allTargets: [TargetItem] {
        whitelistTargets + blacklistTargets
    }
    
    // MARK: - Состояние
    
    @Published public var ipInfo: IpInfo?
    @Published public var isRunning: Bool = false
    @Published public var resultsMap: [String: CheckResult] = [:]
    @Published public var selectedFilter: TargetFilter = .all
    @Published public var searchQuery: String = ""
    @Published public var selectedResultForDetail: CheckResult?
    @Published public var progressCurrent: Int = 0
    
    private var scanTask: Task<Void, Never>?
    
    public init() {
        // Инициализируем словарь результатов пустыми состояниями
        for target in allTargets {
            resultsMap[target.name] = CheckResult(target: target, verdict: .unknown)
        }
    }
    
    // MARK: - Вычисляемые метрики
    
    public var allResultsList: [CheckResult] {
        allTargets.compactMap { resultsMap[$0.name] }
    }
    
    public var filteredResults: [CheckResult] {
        var list: [CheckResult]
        switch selectedFilter {
        case .all:
            list = allResultsList
        case .whitelist:
            list = allResultsList.filter { $0.target.isWhitelist }
        case .blacklist:
            list = allResultsList.filter { !$0.target.isWhitelist }
        case .blocked:
            list = allResultsList.filter { $0.verdict.isBlocked }
        }
        
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchQuery.lowercased()
            list = list.filter {
                $0.target.name.lowercased().contains(q) || $0.target.url.lowercased().contains(q)
            }
        }
        return list
    }
    
    public var whiteOkCount: Int {
        whitelistTargets.filter { resultsMap[$0.name]?.verdict == .ok }.count
    }
    
    public var blackOpenCount: Int {
        blacklistTargets.filter { resultsMap[$0.name]?.verdict == .ok }.count
    }
    
    public var blackBlockedCount: Int {
        blacklistTargets.filter {
            let v = resultsMap[$0.name]?.verdict
            return v != nil && v!.isBlocked
        }.count
    }
    
    public var tlsDpiCount: Int {
        allResultsList.filter { !$0.target.isWhitelist && ($0.verdict == .tlsBlock || $0.verdict == .tcpReset) }.count
    }
    
    public var stubCount: Int {
        allResultsList.filter { !$0.target.isWhitelist && $0.verdict == .httpStub }.count
    }
    
    public var dnsBlockCount: Int {
        allResultsList.filter { !$0.target.isWhitelist && $0.verdict == .dnsBlock }.count
    }
    
    public var timeoutCount: Int {
        allResultsList.filter { !$0.target.isWhitelist && $0.verdict == .timeout }.count
    }
    
    public var verdictBannerText: String {
        if blackBlockedCount == 0 {
            return "→ Блокировок ресурсов из чёрного списка не обнаружено."
        } else if blackBlockedCount == blacklistTargets.count {
            return "→ Полная DPI/ТСПУ блокировка — все ресурсы чёрного списка заблокированы."
        } else {
            return "→ Выборочная DPI/ТСПУ фильтрация (обнаружены частичные блокировки)."
        }
    }
    
    public var verdictBannerColor: Color {
        if blackBlockedCount == 0 {
            return Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0x66 / 255.0)
        } else if blackBlockedCount == blacklistTargets.count {
            return Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0)
        } else {
            return Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0)
        }
    }
    
    // MARK: - Запуск проверок
    
    public func startDiagnostics() {
        guard !isRunning else { return }
        isRunning = true
        progressCurrent = 0
        
        // Предварительное выставление статуса тестирования
        for target in allTargets {
            resultsMap[target.name] = CheckResult(target: target, verdict: .testing)
        }
        
        scanTask = Task {
            // 1. Определение IP и провайдера
            let info = await NetworkDiagnosticsEngine.fetchIpAndProvider()
            if !Task.isCancelled {
                self.ipInfo = info
            }
            
            // 2. Последовательный опрос ресурсов с плавным обновлением UI
            for target in allTargets {
                if Task.isCancelled { break }
                let res = await NetworkDiagnosticsEngine.checkTarget(target)
                if !Task.isCancelled {
                    self.resultsMap[target.name] = res
                    self.progressCurrent += 1
                }
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms интервал
            }
            
            if !Task.isCancelled {
                self.isRunning = false
            }
        }
    }
    
    public func stopDiagnostics() {
        scanTask?.cancel()
        scanTask = nil
        isRunning = false
    }
    
    public func retestSingle(target: TargetItem) {
        resultsMap[target.name] = CheckResult(target: target, verdict: .testing)
        Task {
            let res = await NetworkDiagnosticsEngine.checkTarget(target)
            self.resultsMap[target.name] = res
        }
    }
}

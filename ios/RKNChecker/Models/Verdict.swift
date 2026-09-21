import SwiftUI

/// Статус классификации доступности и детекции блокировок ресурса.
/// Включает визуальные цвета бейджей (полный паритет с Android), SF Symbols и пояснения.
public enum Verdict: String, CaseIterable, Sendable {
    case ok = "OK"
    case httpStub = "HTTP_STUB"
    case tlsBlock = "TLS_BLOCK"
    case tcpReset = "TCP_RESET"
    case dnsBlock = "DNS_BLOCK"
    case timeout = "TIMEOUT"
    case down = "DOWN"
    case testing = "TESTING"
    case unknown = "UNKNOWN"
    
    /// Текстовый лейбл бейджа (в стиле терминального статуса)
    public var label: String {
        switch self {
        case .ok: return "✓ OK"
        case .httpStub: return "✗ HTTP STUB"
        case .tlsBlock: return "~ TLS DPI"
        case .tcpReset: return "~ TCP RESET"
        case .dnsBlock: return "⛔ DNS BLOCK"
        case .timeout: return "? TIMEOUT"
        case .down: return "· DOWN"
        case .testing: return "... TESTING"
        case .unknown: return "? UNKNOWN"
        }
    }
    
    /// Имя системного символа SF Symbols для нативного интерфейса iOS/iPadOS
    public var systemImage: String {
        switch self {
        case .ok: return "checkmark.shield.fill"
        case .httpStub: return "doc.text.magnifyingglass"
        case .tlsBlock: return "lock.slash.fill"
        case .tcpReset: return "arrow.triangle.swap"
        case .dnsBlock: return "network.slash"
        case .timeout: return "clock.badge.exclamationmark"
        case .down: return "xmark.circle"
        case .testing: return "arrow.clockwise"
        case .unknown: return "questionmark.circle"
        }
    }
    
    /// Цвет фона бейджа (соответствует палитре Android)
    public var badgeBg: Color {
        switch self {
        case .ok:
            return Color(red: 0x13 / 255.0, green: 0x38 / 255.0, blue: 0x27 / 255.0)
        case .httpStub, .dnsBlock, .timeout:
            return Color(red: 0x38 / 255.0, green: 0x13 / 255.0, blue: 0x1A / 255.0)
        case .tlsBlock, .tcpReset:
            return Color(red: 0x3D / 255.0, green: 0x32 / 255.0, blue: 0x16 / 255.0)
        case .testing:
            return Color(red: 0x1A / 255.0, green: 0x2B / 255.0, blue: 0x3C / 255.0)
        case .down, .unknown:
            return Color(red: 0x2C / 255.0, green: 0x2C / 255.0, blue: 0x2C / 255.0)
        }
    }
    
    /// Цвет текста и иконки бейджа (соответствует палитре Android)
    public var badgeFg: Color {
        switch self {
        case .ok:
            return Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0x66 / 255.0)
        case .httpStub, .dnsBlock, .timeout:
            return Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0)
        case .tlsBlock, .tcpReset:
            return Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0)
        case .testing:
            return Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
        case .down, .unknown:
            return Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0)
        }
    }
    
    /// Является ли вердикт индикатором блокировки цензурой
    public var isBlocked: Bool {
        switch self {
        case .httpStub, .tlsBlock, .tcpReset, .dnsBlock, .timeout:
            return true
        case .ok, .down, .testing, .unknown:
            return false
        }
    }
    
    /// Развёрнутое описание вердикта
    public var localizedDescription: String {
        switch self {
        case .ok:
            return "Доступен: DNS разрешён, TCP/TLS установлены, тело ответа чистое."
        case .httpStub:
            return "Заглушка провайдера: обнаружен HTTP 451 либо страница блокировки РКН."
        case .tlsBlock:
            return "DPI / ТСПУ: сброс TLS Handshake сразу после ClientHello (фильтрация по SNI)."
        case .tcpReset:
            return "TCP RST: инъекция пакета сброса TCP сетевым фильтром."
        case .dnsBlock:
            return "DNS-блокировка: системный DNS возвращает ошибку, хотя DoH резолвит домен."
        case .timeout:
            return "Таймаут TCP (порт 443): отбрасывание пакетов или блокировка по IP."
        case .down:
            return "Недоступен: домен не резолвится либо сервер выключен."
        case .testing:
            return "Выполняется диагностика..."
        case .unknown:
            return "Статус ещё не определён."
        }
    }
}

import SwiftUI

/// Карточка конкретного целевого ресурса со статусом, вердиктом, замерами таймингов и диагностическими заметками.
public struct SiteResultCardView: View {
    public let result: CheckResult
    public let onTap: () -> Void
    
    public init(result: CheckResult, onTap: @escaping () -> Void = {}) {
        self.result = result
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Верхняя строка: Имя + Тег Whitelist/Blacklist + Бейдж вердикта
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Text(result.target.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Тег Whitelist / Blacklist
                        Text(result.target.isWhitelist ? "WHITELIST" : "BLACKLIST")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(
                                result.target.isWhitelist
                                    ? Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
                                    : Color(red: 0xBF / 255.0, green: 0x5A / 255.0, blue: 0xF2 / 255.0)
                            )
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                (result.target.isWhitelist
                                    ? Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
                                    : Color(red: 0xBF / 255.0, green: 0x5A / 255.0, blue: 0xF2 / 255.0)
                                ).opacity(0.12)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(
                                        (result.target.isWhitelist
                                            ? Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
                                            : Color(red: 0xBF / 255.0, green: 0x5A / 255.0, blue: 0xF2 / 255.0)
                                        ).opacity(0.4),
                                        lineWidth: 1
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    VerdictBadgeView(verdict: result.verdict)
                }
                
                // Строка метрик (TCP, TLS, PLT, Status)
                HStack(spacing: 6) {
                    MetricPillView(label: "TCP", value: result.tcpTimeMs.map { "\($0)ms" } ?? "-")
                    MetricPillView(label: "TLS", value: result.tlsTimeMs.map { "\($0)ms" } ?? "-")
                    MetricPillView(label: "PLT", value: result.pltMs.map { "\($0)ms" } ?? "-")
                    MetricPillView(label: "Status", value: result.statusCode.map { "\($0)" } ?? "-")
                }
                
                // Блок заметок и сигнатур (при наличии)
                if !result.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(result.notes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0))
                                
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0xD1 / 255.0, green: 0xD1 / 255.0, blue: 0xD6 / 255.0))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(red: 0x20 / 255.0, green: 0x20 / 255.0, blue: 0x24 / 255.0))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(12)
            .background(Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x18 / 255.0))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x2A / 255.0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

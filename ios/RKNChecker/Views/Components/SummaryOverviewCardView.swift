import SwiftUI

/// Сводная карточка результатов диагностики (Whitelist/Blacklist, вердикт цензуры и разбивка по типам).
public struct SummaryOverviewCardView: View {
    public let whiteOk: Int
    public let whiteTotal: Int
    public let blackOpen: Int
    public let blackBlocked: Int
    public let blackTotal: Int
    public let bannerText: String
    public let bannerColor: Color
    public let tlsDpiCount: Int
    public let stubCount: Int
    public let dnsCount: Int
    public let timeoutCount: Int
    
    public init(
        whiteOk: Int,
        whiteTotal: Int,
        blackOpen: Int,
        blackBlocked: Int,
        blackTotal: Int,
        bannerText: String,
        bannerColor: Color,
        tlsDpiCount: Int,
        stubCount: Int,
        dnsCount: Int,
        timeoutCount: Int
    ) {
        self.whiteOk = whiteOk
        self.whiteTotal = whiteTotal
        self.blackOpen = blackOpen
        self.blackBlocked = blackBlocked
        self.blackTotal = blackTotal
        self.bannerText = bannerText
        self.bannerColor = bannerColor
        self.tlsDpiCount = tlsDpiCount
        self.stubCount = stubCount
        self.dnsCount = dnsCount
        self.timeoutCount = timeoutCount
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIAGNOSTIC SUMMARY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
            
            // Статистика Whitelist и Blacklist
            HStack(spacing: 10) {
                // Whitelist Box
                VStack(alignment: .leading, spacing: 3) {
                    Text("Whitelist")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                    
                    Text("\(whiteOk) / \(whiteTotal) OK")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0x66 / 255.0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(red: 0x1A / 255.0, green: 0x26 / 255.0, blue: 0x20 / 255.0))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Blacklist Box
                VStack(alignment: .leading, spacing: 3) {
                    Text("Blacklist")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                    
                    Text("\(blackOpen) Open · \(blackBlocked) Blocked")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(
                            blackBlocked > 0
                                ? Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0)
                                : Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0x66 / 255.0)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    blackBlocked > 0
                        ? Color(red: 0x33 / 255.0, green: 0x1E / 255.0, blue: 0x22 / 255.0)
                        : Color(red: 0x1A / 255.0, green: 0x26 / 255.0, blue: 0x20 / 255.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // Баннер вердикта цензуры
            HStack(spacing: 6) {
                Image(systemName: blackBlocked == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(bannerColor)
                    .font(.system(size: 14))
                
                Text(bannerText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(bannerColor)
            }
            .padding(.vertical, 2)
            
            // Детализация блокировок по типам
            if blackBlocked > 0 {
                HStack(spacing: 6) {
                    if tlsDpiCount > 0 {
                        BlockChipView(label: "TLS DPI: \(tlsDpiCount)", color: Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0))
                    }
                    if stubCount > 0 {
                        BlockChipView(label: "HTTP Stub: \(stubCount)", color: Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0))
                    }
                    if dnsCount > 0 {
                        BlockChipView(label: "DNS Block: \(dnsCount)", color: Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0))
                    }
                    if timeoutCount > 0 {
                        BlockChipView(label: "Timeout: \(timeoutCount)", color: Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x18 / 255.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x2A / 255.0), lineWidth: 1)
        )
    }
}

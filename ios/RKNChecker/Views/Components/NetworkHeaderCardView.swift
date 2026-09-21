import SwiftUI

/// Карточка с информацией о текущем внешнем интернет-соединении (IP, провайдер, локация).
public struct NetworkHeaderCardView: View {
    public let ipInfo: IpInfo?
    public let isDetecting: Bool
    
    public init(ipInfo: IpInfo?, isDetecting: Bool = false) {
        self.ipInfo = ipInfo
        self.isDetecting = isDetecting
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CONNECTION INFO")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                
                Spacer()
                
                if isDetecting {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            HStack(alignment: .top, spacing: 16) {
                // IP Address
                VStack(alignment: .leading, spacing: 2) {
                    Text("IP Address")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0x6E / 255.0, green: 0x6E / 255.0, blue: 0x73 / 255.0))
                    
                    Text(ipInfo?.ip ?? (isDetecting ? "Detecting..." : "Unavailable"))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // ISP / Provider
                VStack(alignment: .leading, spacing: 2) {
                    Text("ISP / Provider")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0x6E / 255.0, green: 0x6E / 255.0, blue: 0x73 / 255.0))
                    
                    Text(ipInfo?.isp ?? (isDetecting ? "Detecting..." : "Unavailable"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let loc = ipInfo?.location, !loc.isEmpty, loc != "Unknown" {
                HStack(spacing: 4) {
                    Text("Location:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0x6E / 255.0, green: 0x6E / 255.0, blue: 0x73 / 255.0))
                    Text(loc)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0xD1 / 255.0, green: 0xD1 / 255.0, blue: 0xD6 / 255.0))
                }
                .padding(.top, 2)
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

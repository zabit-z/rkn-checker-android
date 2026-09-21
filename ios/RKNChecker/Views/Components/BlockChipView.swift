import SwiftUI

/// Чип категории блокировки (например, "TLS DPI: 3", "HTTP Stub: 1").
public struct BlockChipView: View {
    public let label: String
    public let color: Color
    
    public init(label: String, color: Color) {
        self.label = label
        self.color = color
    }
    
    public var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}

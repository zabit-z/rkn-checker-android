import SwiftUI

/// Компактная плашка метрики задержки или статуса (TCP, TLS, PLT, Status).
public struct MetricPillView: View {
    public let label: String
    public let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Text("\(label):")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
            
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(red: 0x22 / 255.0, green: 0x22 / 255.0, blue: 0x26 / 255.0))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

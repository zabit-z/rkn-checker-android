import SwiftUI

/// Бейдж вердикта проверки с цветовой кодировкой и системным символом.
public struct VerdictBadgeView: View {
    public let verdict: Verdict
    
    public init(verdict: Verdict) {
        self.verdict = verdict
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: verdict.systemImage)
                .font(.system(size: 10, weight: .bold))
            
            Text(verdict.label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundColor(verdict.badgeFg)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(verdict.badgeBg)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

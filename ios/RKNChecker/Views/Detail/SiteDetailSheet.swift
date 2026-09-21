import SwiftUI

/// Подробный инспектор технической информации о ресурсе (сравнение DNS, заголовки, сырые замеры).
public struct SiteDetailSheet: View {
    public let result: CheckResult
    public let onRetest: (TargetItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    public init(result: CheckResult, onRetest: @escaping (TargetItem) -> Void = { _ in }) {
        self.result = result
        self.onRetest = onRetest
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Шапка: Имя, URL, вердикт
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(result.target.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            VerdictBadgeView(verdict: result.verdict)
                        }
                        
                        Text(result.target.url)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                        
                        Text(result.verdict.localizedDescription)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                            .padding(.top, 2)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x18 / 255.0))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Блок 1: DNS анализ
                    SectionCard(title: "1. DNS АНАЛИЗ", icon: "network") {
                        DetailRow(label: "System DNS IP", value: result.sysIp ?? "Ошибка / Не разрешён")
                        DetailRow(label: "Cloudflare DoH IP", value: result.dohIp ?? "Не разрешён")
                        DetailRow(
                            label: "Подмена DNS (Mismatch)",
                            value: result.dnsMismatch ? "ОБНАРУЖЕНА" : "Совпадает / Чисто",
                            valueColor: result.dnsMismatch ? Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0) : .white
                        )
                    }
                    
                    // Блок 2: TCP замер (порт 443)
                    SectionCard(title: "2. TCP СОЕДИНЕНИЕ (Port 443)", icon: "bolt.horizontal") {
                        DetailRow(label: "TCP Connect", value: result.tcpOk ? "Установлено" : "Не удалось", valueColor: result.tcpOk ? Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0x66 / 255.0) : Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0))
                        DetailRow(label: "TCP RTT", value: result.tcpTimeMs.map { "\($0) мс" } ?? "-")
                        if let err = result.tcpError {
                            DetailRow(label: "TCP Ошибка", value: err, valueColor: Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0))
                        }
                    }
                    
                    // Блок 3: TLS рукопожатие & SNI
                    SectionCard(title: "3. TLS HANDSHAKE & SNI DPI", icon: "lock.shield") {
                        DetailRow(label: "TLS Handshake", value: result.tlsOk ? "Успешно" : "Сброшено / Ошибка", valueColor: result.tlsOk ? Color(red: 0x00 / 255.0, green: 0xFF / 255.0, blue: 0x66 / 255.0) : Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0))
                        DetailRow(label: "TLS Время", value: result.tlsTimeMs.map { "\($0) мс" } ?? "-")
                        DetailRow(label: "SNI Хост", value: result.target.host)
                        if let err = result.tlsError {
                            DetailRow(label: "TLS Ошибка", value: err, valueColor: Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0))
                        }
                    }
                    
                    // Блок 4: HTTP ответ & заглушка
                    SectionCard(title: "4. HTTP ПРОВЕРКА & ЗАГЛУШКИ", icon: "doc.text") {
                        DetailRow(label: "HTTP Код", value: result.statusCode.map { "\($0)" } ?? "-")
                        DetailRow(label: "Время ответа (PLT)", value: result.pltMs.map { "\($0) мс" } ?? "-")
                        if let err = result.httpError {
                            DetailRow(label: "HTTP Ошибка", value: err)
                        }
                    }
                    
                    // Заметки
                    if !result.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ДИАГНОСТИЧЕСКИЕ СИГНАТУРЫ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                            
                            ForEach(result.notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .foregroundColor(Color(red: 0xFF / 255.0, green: 0xCC / 255.0, blue: 0x00 / 255.0))
                                    Text(note)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0xD1 / 255.0, green: 0xD1 / 255.0, blue: 0xD6 / 255.0))
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0x20 / 255.0, green: 0x20 / 255.0, blue: 0x24 / 255.0))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    // Кнопка повторного тестирования
                    Button(action: {
                        onRetest(result.target)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Повторить проверку ресурса")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .background(Color(red: 0x0C / 255.0, green: 0x0C / 255.0, blue: 0x0C / 255.0).ignoresSafeArea())
            .navigationTitle("Технический отчёт")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
            }
            
            VStack(spacing: 6) {
                content()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x18 / 255.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x2A / 255.0), lineWidth: 1)
        )
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(valueColor)
        }
    }
}

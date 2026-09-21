import SwiftUI

/// Главный адаптивный экран приложения.
/// Автоматически переключается между iPad (NavigationSplitView с боковой панелью)
/// и iPhone / компактным режимом многозадачности (NavigationStack с вертикальным потоком).
public struct MainAdaptiveView: View {
    @StateObject private var viewModel = CheckerViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init() {}
    
    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // Планшетный интерфейс iPadOS
                iPadSplitContainerView(viewModel: viewModel)
            } else {
                // Телефонный интерфейс iOS / Компактный iPad Split View
                iPhoneLayoutView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.startDiagnostics()
        }
    }
}

/// Мобильный интерфейс для iPhone и компактного режима iPad (Slide Over, 1/3 Split View).
private struct iPhoneLayoutView: View {
    @ObservedObject var viewModel: CheckerViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar (полный аналог Android Header Bar)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RKN BLOCK CHECKER")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundColor(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                        
                        Text(viewModel.isRunning ? "Scanning connection (\(viewModel.progressCurrent)/\(viewModel.allTargets.count))..." : "Diagnostics Ready")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if viewModel.isRunning {
                            viewModel.stopDiagnostics()
                        } else {
                            viewModel.startDiagnostics()
                        }
                    }) {
                        if viewModel.isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)))
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0x14 / 255.0, green: 0x14 / 255.0, blue: 0x14 / 255.0))
                
                // Основной контент со скроллом
                ScrollView {
                    LazyVStack(spacing: 10) {
                        // 1. Connection Header Card
                        NetworkHeaderCardView(ipInfo: viewModel.ipInfo, isDetecting: viewModel.isRunning)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                        
                        // 2. Summary Overview Card
                        SummaryOverviewCardView(
                            whiteOk: viewModel.whiteOkCount,
                            whiteTotal: viewModel.whitelistTargets.count,
                            blackOpen: viewModel.blackOpenCount,
                            blackBlocked: viewModel.blackBlockedCount,
                            blackTotal: viewModel.blacklistTargets.count,
                            bannerText: viewModel.verdictBannerText,
                            bannerColor: viewModel.verdictBannerColor,
                            tlsDpiCount: viewModel.tlsDpiCount,
                            stubCount: viewModel.stubCount,
                            dnsCount: viewModel.dnsBlockCount,
                            timeoutCount: viewModel.timeoutCount
                        )
                        .padding(.horizontal, 14)
                        
                        // 3. Filter Tabs (All, Whitelist, Blacklist, Blocked)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(
                                    title: "All (\(viewModel.allResultsList.count))",
                                    isSelected: viewModel.selectedFilter == .all
                                ) {
                                    viewModel.selectedFilter = .all
                                }
                                
                                FilterChip(
                                    title: "Whitelist (\(viewModel.whitelistTargets.count))",
                                    isSelected: viewModel.selectedFilter == .whitelist
                                ) {
                                    viewModel.selectedFilter = .whitelist
                                }
                                
                                FilterChip(
                                    title: "Blacklist (\(viewModel.blacklistTargets.count))",
                                    isSelected: viewModel.selectedFilter == .blacklist
                                ) {
                                    viewModel.selectedFilter = .blacklist
                                }
                                
                                FilterChip(
                                    title: "Blocked (\(viewModel.blackBlockedCount))",
                                    isSelected: viewModel.selectedFilter == .blocked
                                ) {
                                    viewModel.selectedFilter = .blocked
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                        
                        // 4. Поиск
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                                .font(.system(size: 13))
                            
                            TextField("Поиск ресурса...", text: $viewModel.searchQuery)
                                .font(.system(size: 13))
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                            
                            if !viewModel.searchQuery.isEmpty {
                                Button(action: { viewModel.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                                        .font(.system(size: 13))
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(red: 0x18 / 255.0, green: 0x18 / 255.0, blue: 0x1B / 255.0))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(red: 0x2A / 255.0, green: 0x2A / 255.0, blue: 0x2E / 255.0), lineWidth: 1)
                        )
                        .padding(.horizontal, 14)
                        
                        // 5. Карточки ресурсов
                        ForEach(viewModel.filteredResults) { result in
                            SiteResultCardView(result: result) {
                                viewModel.selectedResultForDetail = result
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color(red: 0x0C / 255.0, green: 0x0C / 255.0, blue: 0x0C / 255.0).ignoresSafeArea())
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .sheet(item: $viewModel.selectedResultForDetail) { result in
                SiteDetailSheet(result: result) { target in
                    viewModel.retestSingle(target: target)
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundColor(
                    isSelected
                        ? Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
                        : Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0).opacity(0.12)
                        : Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1D / 255.0)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0).opacity(0.4)
                                : Color(red: 0x2A / 255.0, green: 0x2A / 255.0, blue: 0x2E / 255.0),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

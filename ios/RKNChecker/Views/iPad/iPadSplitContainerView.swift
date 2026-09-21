import SwiftUI

/// Двухпанельный макет на базе NavigationSplitView для iPadOS.
/// Полноценно использует широкое рабочее пространство планшета, поддерживает Split View и Slide Over.
public struct iPadSplitContainerView: View {
    @ObservedObject public var viewModel: CheckerViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    public init(viewModel: CheckerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Боковая панель (Sidebar)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Карточка соединения
                    NetworkHeaderCardView(ipInfo: viewModel.ipInfo, isDetecting: viewModel.isRunning)
                    
                    // Кнопка запуска / остановки диагностики
                    Button(action: {
                        if viewModel.isRunning {
                            viewModel.stopDiagnostics()
                        } else {
                            viewModel.startDiagnostics()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isRunning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                                Text("Остановить (\(viewModel.progressCurrent)/\(viewModel.allTargets.count))")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Запустить диагностику")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    // Список категорий фильтрации
                    VStack(alignment: .leading, spacing: 6) {
                        Text("КАТЕГОРИИ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                            .padding(.horizontal, 4)
                        
                        FilterButton(
                            title: "Все ресурсы",
                            icon: "list.bullet",
                            count: viewModel.allResultsList.count,
                            isSelected: viewModel.selectedFilter == .all,
                            color: Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
                        ) {
                            viewModel.selectedFilter = .all
                        }
                        
                        FilterButton(
                            title: "Whitelist",
                            icon: "checkmark.shield",
                            count: viewModel.whitelistTargets.count,
                            subCount: "\(viewModel.whiteOkCount) OK",
                            isSelected: viewModel.selectedFilter == .whitelist,
                            color: Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0)
                        ) {
                            viewModel.selectedFilter = .whitelist
                        }
                        
                        FilterButton(
                            title: "Blacklist",
                            icon: "shield.slash",
                            count: viewModel.blacklistTargets.count,
                            subCount: "\(viewModel.blackBlockedCount) Blocked",
                            isSelected: viewModel.selectedFilter == .blacklist,
                            color: Color(red: 0xBF / 255.0, green: 0x5A / 255.0, blue: 0xF2 / 255.0)
                        ) {
                            viewModel.selectedFilter = .blacklist
                        }
                        
                        FilterButton(
                            title: "Заблокировано",
                            icon: "xmark.octagon",
                            count: viewModel.blackBlockedCount,
                            isSelected: viewModel.selectedFilter == .blocked,
                            color: Color(red: 0xFF / 255.0, green: 0x33 / 255.0, blue: 0x66 / 255.0)
                        ) {
                            viewModel.selectedFilter = .blocked
                        }
                    }
                }
                .padding()
            }
            .background(Color(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x13 / 255.0))
            .navigationTitle("RKN Checker")
            
        } detail: {
            // MARK: - Основной холст (Detail Canvas)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Сводная карточка
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
                    
                    // Поисковая строка и счётчик
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                            
                            TextField("Поиск по имени или домену...", text: $viewModel.searchQuery)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                            
                            if !viewModel.searchQuery.isEmpty {
                                Button(action: { viewModel.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        Text("Найдено: \(viewModel.filteredResults.count)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                            .padding(.leading, 8)
                    }
                    
                    // Сетка карточек для iPad
                    if viewModel.filteredResults.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0x48 / 255.0, green: 0x48 / 255.0, blue: 0x4A / 255.0))
                            Text("Нет ресурсов, соответствующих фильтру")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        iPadGridView(results: viewModel.filteredResults) { result in
                            viewModel.selectedResultForDetail = result
                        }
                    }
                }
                .padding()
            }
            .background(Color(red: 0x0C / 255.0, green: 0x0C / 255.0, blue: 0x0C / 255.0).ignoresSafeArea())
            .navigationTitle(viewModel.selectedFilter.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.startDiagnostics() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(red: 0x00 / 255.0, green: 0xE5 / 255.0, blue: 0xFF / 255.0))
                    }
                    .disabled(viewModel.isRunning)
                }
            }
            .sheet(item: $viewModel.selectedResultForDetail) { result in
                SiteDetailSheet(result: result) { target in
                    viewModel.retestSingle(target: target)
                }
            }
        }
    }
}

private struct FilterButton: View {
    let title: String
    let icon: String
    let count: Int
    var subCount: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? color : Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color(red: 0xAE / 255.0, green: 0xAE / 255.0, blue: 0xB2 / 255.0))
                
                Spacer()
                
                if let sub = subCount {
                    Text(sub)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                        .padding(.trailing, 4)
                }
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : Color(red: 0x6E / 255.0, green: 0x6E / 255.0, blue: 0x73 / 255.0))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0x22 / 255.0, green: 0x22 / 255.0, blue: 0x26 / 255.0))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                isSelected
                    ? Color(red: 0x1E / 255.0, green: 0x1E / 255.0, blue: 0x24 / 255.0)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

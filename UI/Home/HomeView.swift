import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showServerList = false
    @State private var showSettings = false
    @State private var showDiagnostics = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Фон приложения
            Color.appBackground
                .ignoresSafeArea()
            
            // Фоновое фокусное свечение
            VStack {
                Circle()
                    .fill(Color.appRed.opacity(viewModel.connectionStatus == .connected ? 0.15 : 0.05))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(y: -40)
                Spacer()
            }
            .ignoresSafeArea()
            
            // Основной скроллируемый контент (гарантирует отсутствие обрезки на iPhone 7)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    // Верхняя панель (Header)
                    headerSection
                        .padding(.top, 8)
                    
                    // Статус подключения
                    StatusBadge(status: viewModel.connectionStatus)
                    
                    Spacer(minLength: 12)
                    
                    // Центральная кнопка подключения
                    ConnectButton(status: viewModel.connectionStatus) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleConnection()
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Таймер сессии (виден при активном подключении)
                    if viewModel.connectionStatus == .connected {
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2.0)
                            .transition(.opacity)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Карточка выбранного сервера
                    serverSelectionCard
                    
                    // Блок сообщения об ошибке
                    if let err = viewModel.errorMessage, viewModel.connectionStatus == .error {
                        errorBanner(err)
                    }
                    
                    // Дополнительные кнопки навигации
                    bottomQuickActions
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showServerList) {
            ServerListView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FEDERAL VPN")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.5)
                
                Text("ИНТЕРНЕТ БЕЗ ГРАНИЦ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appRed)
                    .tracking(1.2)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showDiagnostics = true }) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                }
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private var serverSelectionCard: some View {
        Button(action: { showServerList = true }) {
            GlassCard(cornerRadius: 16, padding: 14) {
                HStack(spacing: 14) {
                    // Флаг в круглой плашке
                    Text(viewModel.selectedServer?.flag ?? "🌐")
                        .font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.selectedServer?.name ?? "Выберите сервер")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(viewModel.selectedServer?.address ?? "Нажмите для выбора локации")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Пинг / задержка
                    if let ping = viewModel.selectedServer?.latency {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ping < 100 ? Color.appGreen : Color.appYellow)
                                .frame(width: 6, height: 6)
                            Text("\(ping) ms")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.appTextMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.appRed)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(Color.appRedDark.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appRed.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var bottomQuickActions: some View {
        HStack {
            Text("VLESS • REALITY • XTLS VISION")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.appTextMuted)
                .tracking(1.0)
        }
    }
}

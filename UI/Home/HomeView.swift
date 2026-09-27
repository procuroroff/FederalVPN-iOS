import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showServerList = false
    @State private var showSettings = false
    @State private var showDiagnostics = false
    @State private var showLogin = false
    @State private var showCabinet = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Темный фон
            Color.appBackground
                .ignoresSafeArea()
            
            // Фоновое фокусное свечение
            VStack {
                Circle()
                    .fill(Color.appRed.opacity(viewModel.connectionStatus == .connected ? 0.16 : 0.06))
                    .frame(width: 320, height: 320)
                    .blur(radius: 65)
                    .offset(y: -50)
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. Верхний хедер
                    headerSection
                        .padding(.top, 6)
                    
                    // 2. Карточка авторизации / профиля пользователя (как на Android)
                    if viewModel.isAuthenticated, let profile = viewModel.userProfile {
                        accountCard(profile)
                    } else {
                        guestCard
                    }
                    
                    // 3. Статус подключения
                    StatusBadge(status: viewModel.connectionStatus)
                        .padding(.top, 4)
                    
                    // 4. Большая кнопка подключения с анимацией
                    ConnectButton(status: viewModel.connectionStatus) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.toggleConnection()
                        }
                    }
                    .padding(.vertical, 6)
                    
                    // 5. Таймер активной сессии
                    if viewModel.connectionStatus == .connected {
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2.0)
                            .transition(.opacity)
                    }
                    
                    // 6. Карточка выбора сервера
                    serverSelectionCard
                    
                    // 7. Сообщение об ошибке (при наличии)
                    if let err = viewModel.errorMessage, viewModel.connectionStatus == .error {
                        errorBanner(err)
                    }
                    
                    // 8. Футер протокола
                    protocolFooter
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
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
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showCabinet) {
            CabinetView()
        }
    }
    
    // MARK: - Хедер (с фирменной иконкой и кнопками)
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Логотип приложения (из ассетов с fallback на Shield)
            Group {
                if let uiImage = UIImage(named: "AppLogo") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient.appRedGradient)
                            .frame(width: 44, height: 44)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
            }
            .shadow(color: Color.appRed.opacity(0.3), radius: 6)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("FEDERAL VPN")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)
                
                Text("ИНТЕРНЕТ БЕЗ ГРАНИЦ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.appRed)
                    .tracking(1.0)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Кнопка Кабинета
                Button(action: {
                    if viewModel.isAuthenticated {
                        showCabinet = true
                    } else {
                        showLogin = true
                    }
                }) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.isAuthenticated ? Color.appRed : Color.white)
                        .frame(width: 38, height: 38)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                }
                
                // Кнопка Логов/Диагностики
                Button(action: { showDiagnostics = true }) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.appTextSecondary)
                        .frame(width: 38, height: 38)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                }
                
                // Кнопка Настроек
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.appTextSecondary)
                        .frame(width: 38, height: 38)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Карточка Гостя (Не авторизован)
    
    private var guestCard: some View {
        GlassCard(cornerRadius: 18, padding: 16, showRedBorder: true) {
            VStack(spacing: 12) {
                Text("🔒 ТРЕБУЕТСЯ АВТОРИЗАЦИЯ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appRed)
                    .tracking(1.0)
                
                Text("Войдите под своей учётной записью с сайта federal-vpn.site для подключения к серверам")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                
                Button(action: { showLogin = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient.appRedGradient)
                            .frame(height: 46)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("ВОЙТИ В ЛИЧНЫЙ КАБИНЕТ")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Карточка Авторизованного профиля
    
    private func accountCard(_ profile: UserProfile) -> some View {
        Button(action: { showCabinet = true }) {
            GlassCard(cornerRadius: 18, padding: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.appRedGradient)
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(profile.username)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Circle()
                                .fill(Color.appGreen)
                                .frame(width: 7, height: 7)
                        }
                        
                        Text(profile.formattedExpiryDate)
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(profile.formattedDaysRemaining)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(profile.isInfinite ? Color.appYellow : Color.appGreen)
                        
                        Text("подписка")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appTextMuted)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appTextMuted)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Карточка выбора сервера
    
    private var serverSelectionCard: some View {
        Button(action: { showServerList = true }) {
            GlassCard(cornerRadius: 18, padding: 14) {
                HStack(spacing: 14) {
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
        .background(Color.appRedDark.opacity(0.35))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appRed.opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var protocolFooter: some View {
        HStack {
            Text("VLESS • REALITY • XTLS VISION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.appTextMuted)
                .tracking(1.2)
        }
    }
}

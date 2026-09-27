import SwiftUI

public struct SettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showLogin = false
    @State private var showDiagnostics = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Настройки")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Блок аккаунта
                        accountSection
                        
                        // Тема оформления
                        themeSection
                        
                        // Параметры подключения
                        connectionSettingsSection
                        
                        // Безопасность и DNS
                        securitySection
                        
                        // Кнопки действий
                        actionsSection
                        
                        // Версия приложения
                        versionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
    }
    
    // MARK: - Sections
    
    private var accountSection: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("АККАУНТ И ПОДПИСКА")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextMuted)
                
                if let profile = viewModel.userProfile {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.username)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Активна • осталось \(profile.daysLeft) дн.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appGreen)
                        }
                        
                        Spacer()
                        
                        Button("Выйти") {
                            viewModel.signOut()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appRed)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Гостевой режим")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Войдите для синхронизации подписки")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        
                        Spacer()
                        
                        Button("Войти") {
                            showLogin = true
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.appRed)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var themeSection: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ТЕМА ОФОРМЛЕНИЯ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appTextMuted)
                    Spacer()
                    Text(themeManager.currentTheme.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: {
                            themeManager.setTheme(theme)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(theme.gradient)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: themeManager.currentTheme == theme ? theme.glowColor : .clear, radius: 8)
                                
                                if themeManager.currentTheme == theme {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2.5)
                                        .frame(width: 46, height: 46)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var connectionSettingsSection: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("ПОДКЛЮЧЕНИЕ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextMuted)
                
                Toggle(isOn: Binding(
                    get: { viewModel.isAutoConnect },
                    set: { viewModel.updateAutoConnect($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Автоподключение")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Подключать лучший сервер при запуске")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.appRed))
                
                Divider().background(Color.white.opacity(0.1))
                
                Toggle(isOn: Binding(
                    get: { viewModel.isConnectOnLaunch },
                    set: { viewModel.updateConnectOnLaunch($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Подключаться при открытии")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Активировать туннель сразу при входе")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.appRed))
            }
        }
    }
    
    private var securitySection: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("БЕЗОПАСНОСТЬ И DNS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextMuted)
                
                Toggle(isOn: Binding(
                    get: { viewModel.isKillSwitch },
                    set: { viewModel.updateKillSwitch($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kill Switch (Защита от утечек)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Блокировать трафик при сбое VPN")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.appRed))
                
                Divider().background(Color.white.opacity(0.1))
                
                Toggle(isOn: Binding(
                    get: { viewModel.isLoggingEnabled },
                    set: { viewModel.updateLogging($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Диагностическое логирование")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Запись анонимных логов без секретов")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.appRed))
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { viewModel.refreshSubscription() }) {
                GlassCard(cornerRadius: 14, padding: 14) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color.appRed)
                        Text("Обновить подписку")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        if viewModel.isRefreshingSubscription {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showDiagnostics = true }) {
                GlassCard(cornerRadius: 14, padding: 14) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(Color.appYellow)
                        Text("Диагностика сети")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.appTextMuted)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Federal VPN for iOS")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextSecondary)
            Text("Версия \(viewModel.appVersion)")
                .font(.system(size: 11))
                .foregroundColor(Color.appTextMuted)
        }
        .padding(.top, 8)
    }
}

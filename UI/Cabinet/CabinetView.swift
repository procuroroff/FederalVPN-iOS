import SwiftUI

/// Личный кабинет пользователя Federal VPN (полный функционал и дизайн как в Android CabinetActivity)
public struct CabinetView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var authService = AuthService.shared
    
    @State private var deviceToDelete: ConnectedDevice?
    @State private var showDeleteAlert: Bool = false
    @State private var showLogoutAlert: Bool = false
    @State private var toastMessage: String?
    @State private var showToast: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (как в Android: Назад, Заголовок, Обновить)
                HStack(spacing: 12) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    
                    Text("Личный кабинет")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        triggerRefresh()
                    }) {
                        if authService.isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                    .disabled(authService.isRefreshing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 16) {
                        if let profile = authService.currentUserProfile {
                            // 1. Карточка профиля (Аватар с первой буквой, логин, статус, Telegram)
                            GlassCard(cornerRadius: 18, padding: 18) {
                                HStack(spacing: 16) {
                                    // Круглый аватар с первой буквой логина (как в Android tvAvatarChar)
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient.appRedGradient)
                                            .frame(width: 54, height: 54)
                                        Text(String(profile.username.prefix(1)).uppercased())
                                            .font(.system(size: 24, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.username)
                                            .font(.system(size: 19, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        if let tg = profile.tgUsername, !tg.isEmpty {
                                            Text("@\(tg)")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.appTextSecondary)
                                        } else if profile.telegramLinked {
                                            Text("Telegram привязан")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.appGreen)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Status Badge (АКТИВНА)
                                    Text(profile.isActive ? "АКТИВНА" : profile.accountStatus)
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(profile.isActive ? Color.appGreen : Color.appTextMuted)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background((profile.isActive ? Color.appGreen : Color.white).opacity(0.12))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke((profile.isActive ? Color.appGreen : Color.white).opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            
                            // 2. Карточка тарифа (Дни, Дата окончания, Трафик)
                            GlassCard(cornerRadius: 18, padding: 18) {
                                VStack(spacing: 14) {
                                    HStack(alignment: .center) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Осталось дней")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.appTextSecondary)
                                            Text(profile.formattedExpiryDate)
                                                .font(.system(size: 11))
                                                .foregroundColor(Color.appTextMuted)
                                        }
                                        Spacer()
                                        Text(profile.formattedDaysRemaining)
                                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                                            .foregroundColor(profile.isInfinite ? Color.appYellow : Color.white)
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.08))
                                    
                                    HStack {
                                        Text("Трафик")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text(profile.formattedTraffic)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.08))
                                    
                                    HStack {
                                        Text("Протокол")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text("VLESS REALITY")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color.appRed)
                                    }
                                }
                            }
                            
                            // 3. Секция устройств (как в Android tvDeviceCountBadge + layoutDevicesList)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Подключённые устройства")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(authService.connectedDevices.count) / 5 устройств")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.appTextSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 4)
                                
                                if authService.connectedDevices.isEmpty {
                                    GlassCard(cornerRadius: 16, padding: 18) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "iphone.slash")
                                                .font(.system(size: 28))
                                                .foregroundColor(Color.appTextMuted)
                                            Text("Нет активных устройств")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color.appTextSecondary)
                                            Text("Подключитесь с телефона, и оно появится здесь.")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.appTextMuted)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(authService.connectedDevices) { device in
                                            deviceRow(device)
                                        }
                                    }
                                }
                            }
                            
                            // 4. Кнопка "Продлить подписку" (как в Android btnExtendSub)
                            Button(action: {
                                if let url = URL(string: "https://federal-vpn.site/cabinet.html") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "globe")
                                        .foregroundColor(.white)
                                    Text("Продлить подписку на сайте")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .background(LinearGradient.appRedGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.appRed.opacity(0.3), radius: 8, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 4)
                            
                            // 5. Кнопка "Выйти из аккаунта" (как в Android btnLogout с подтверждением)
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                GlassCard(cornerRadius: 14, padding: 14, showRedBorder: true) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(Color.appRed)
                                        Text("Выйти из аккаунта")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.appRed)
                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                        } else {
                            // Не авторизован
                            GlassCard(cornerRadius: 18, padding: 24) {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color.appYellow)
                                    Text("Вы не вошли в аккаунт")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Войдите в личный кабинет на главном экране для управления подпиской и слотами устройств.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.appTextSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            
            // Toast notification
            if showToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showToast)
            }
        }
        .onAppear {
            Task {
                await authService.refreshAll()
            }
        }
        .alert("Удалить устройство?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let dev = deviceToDelete {
                    performDelete(device: dev)
                }
            }
        } message: {
            if let dev = deviceToDelete {
                Text("Отключить \(dev.displayName) от подписки? Это освободит один слот подключения.")
            } else {
                Text("Отключить выбранное устройство?")
            }
        }
        .alert("Выход из аккаунта", isPresented: $showLogoutAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Выйти", role: .destructive) {
                authService.signOut()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Вы уверены, что хотите выйти из личного кабинета?")
        }
    }
    
    // MARK: - Строка устройства (item_cabinet_device)
    @ViewBuilder
    private func deviceRow(_ device: ConnectedDevice) -> some View {
        GlassCard(cornerRadius: 14, padding: 14) {
            HStack(spacing: 12) {
                // Иконка устройства
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconForPlatform(device.platform))
                        .font(.system(size: 18))
                        .foregroundColor(Color.appTextSecondary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(device.displayMeta)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextMuted)
                }
                
                Spacer()
                
                // Кнопка удаления устройства (как в Android btnDeleteDevice)
                Button(action: {
                    deviceToDelete = device
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(Color.appRed.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(Color.appRed.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func iconForPlatform(_ platform: String) -> String {
        let p = platform.lowercased()
        if p.contains("ios") || p.contains("iphone") || p.contains("apple") {
            return "iphone"
        } else if p.contains("ipad") {
            return "ipad"
        } else if p.contains("android") {
            return "phone.fill"
        } else if p.contains("windows") || p.contains("mac") || p.contains("linux") {
            return "laptopcomputer"
        }
        return "antenna.radiowaves.left.and.right"
    }
    
    private func triggerRefresh() {
        displayToast("Обновление данных...")
        Task {
            await authService.refreshAll()
        }
    }
    
    private func performDelete(device: ConnectedDevice) {
        Task {
            let result = await authService.deleteDevice(hwid: device.hwid)
            await MainActor.run {
                displayToast(result.message)
            }
        }
    }
    
    private func displayToast(_ msg: String) {
        toastMessage = msg
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showToast = false
        }
    }
}

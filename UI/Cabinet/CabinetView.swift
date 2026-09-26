import SwiftUI

public struct CabinetView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var authService = AuthService.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Личный кабинет")
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
                    VStack(spacing: 16) {
                        if let profile = authService.currentUserProfile {
                            // Карточка профиля
                            GlassCard(cornerRadius: 18, padding: 18) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient.appRedGradient)
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.username)
                                            .font(.system(size: 19, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color.appGreen)
                                                .frame(width: 7, height: 7)
                                            Text("ПОДПИСКА АКТИВНА")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color.appGreen)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            
                            // Карточка параметров подписки
                            GlassCard(cornerRadius: 18, padding: 18) {
                                VStack(spacing: 14) {
                                    HStack {
                                        Text("Срок действия")
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text(profile.formattedDaysRemaining)
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundColor(profile.isInfinite ? Color.appYellow : Color.white)
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    HStack {
                                        Text("Статус")
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text(profile.formattedExpiryDate)
                                            .foregroundColor(Color.white)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    HStack {
                                        Text("Протокол")
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text("VLESS REALITY Vision")
                                            .foregroundColor(Color.appRed)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    }
                                }
                            }
                            
                            // Информационная карточка безопасности
                            GlassCard(cornerRadius: 18, padding: 18) {
                                HStack(spacing: 14) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color.appGreen)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Статус безопасности")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Прямое сквозное шифрование активных сессий")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                }
                            }
                            
                            // Кнопка выхода
                            Button(action: {
                                authService.signOut()
                                presentationMode.wrappedValue.dismiss()
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
                            .padding(.top, 8)
                            
                        } else {
                            Text("Вы не авторизованы")
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

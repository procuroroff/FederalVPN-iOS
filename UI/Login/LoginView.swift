import SwiftUI

public struct LoginView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = LoginViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack {
                Circle()
                    .fill(Color.appRed.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    .padding(.top, 12)
                    
                    // Logo & Slogan
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 54))
                            .foregroundColor(Color.appRed)
                            .padding(.bottom, 6)
                        
                        Text("FEDERAL VPN")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2.0)
                        
                        Text("Вход в персональный аккаунт")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(.vertical, 16)
                    
                    // Input Card
                    GlassCard(cornerRadius: 18, padding: 20) {
                        VStack(spacing: 16) {
                            // Логин
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ЛОГИН")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.appTextMuted)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                    TextField("Введите логин", text: $viewModel.username)
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding(12)
                                .background(Color.appSurfaceElevated)
                                .cornerRadius(10)
                            }
                            
                            // Пароль
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ПАРОЛЬ")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.appTextMuted)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                    SecureField("Введите пароль", text: $viewModel.password)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .background(Color.appSurfaceElevated)
                                .cornerRadius(10)
                            }
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.appRed)
                                    .padding(.top, 4)
                            }
                            
                            // Кнопка Входа
                            Button(action: {
                                viewModel.signIn { success in
                                    if success {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient.appRedGradient)
                                        .frame(height: 50)
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("ВОЙТИ В СИСТЕМУ")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                            .tracking(1.0)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(viewModel.isLoading)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }
}

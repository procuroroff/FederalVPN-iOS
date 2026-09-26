import SwiftUI

public struct ServerListView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = ServerListViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                navigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 14) {
                        // Кнопка Автовыбора
                        autoSelectionCard
                        
                        // Список доступных серверов
                        ForEach(viewModel.servers) { server in
                            serverCard(server)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            viewModel.refreshPings()
        }
    }
    
    private var navigationBar: some View {
        HStack {
            Text("Локации")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
    }
    
    private var autoSelectionCard: some View {
        Button(action: {
            viewModel.performAutoSelection { _ in
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            GlassCard(cornerRadius: 16, padding: 14, showRedBorder: true) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appRedDark.opacity(0.4))
                            .frame(width: 44, height: 44)
                        
                        if viewModel.isAutoSelecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.appRed)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Автоматический выбор")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Самый низкий пинг и надежность")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .foregroundColor(Color.appYellow)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isAutoSelecting)
    }
    
    private func serverCard(_ server: Server) -> some View {
        let isSelected = viewModel.selectedServer?.id == server.id
        
        return Button(action: {
            viewModel.selectServer(server)
            presentationMode.wrappedValue.dismiss()
        }) {
            GlassCard(cornerRadius: 14, padding: 14, showRedBorder: isSelected) {
                HStack(spacing: 12) {
                    Text(server.flag)
                        .font(.system(size: 26))
                        .frame(width: 42, height: 42)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(server.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(server.country)
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    // Пинг
                    if let ping = server.latency {
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
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appRed)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

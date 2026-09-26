import SwiftUI

public struct DiagnosticsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = DiagnosticsViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Диагностика")
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
                        // Карточка системных метрик
                        metricsCard
                        
                        // Кнопка копирования
                        copyButton
                        
                        // Логи в реальном времени
                        logsConsoleCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            viewModel.refreshLogs()
        }
    }
    
    private var metricsCard: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(spacing: 12) {
                metricRow(title: "Connection status", value: viewModel.connectionStatus)
                metricRow(title: "Selected server", value: viewModel.selectedServerName)
                metricRow(title: "Latency", value: viewModel.latencyString)
                metricRow(title: "Network type", value: viewModel.networkType)
                metricRow(title: "Tunnel status", value: viewModel.tunnelStatus)
                metricRow(title: "Core status", value: viewModel.coreStatus)
                metricRow(title: "Last error", value: viewModel.lastError, isError: viewModel.lastError != "Нет ошибок" && viewModel.lastError != "Нет")
            }
        }
    }
    
    private func metricRow(title: String, value: String, isError: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(isError ? Color.appRed : .white)
                .lineLimit(1)
        }
    }
    
    private var copyButton: some View {
        Button(action: {
            viewModel.copyDiagnosticsToClipboard()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.isCopied ? Color.appGreen : Color.appSurfaceElevated)
                    .frame(height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isCopied ? "checkmark" : "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.isCopied ? "СКОПИРОВАНО В БУФЕР" : "СКОПИРОВАТЬ ДИАГНОСТИКУ")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var logsConsoleCard: some View {
        GlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("СИСТЕМНЫЙ ЖУРНАЛ (БЕЗ СЕКРЕТОВ)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appTextMuted)
                    Spacer()
                    Button("Очистить") {
                        AppLogger.shared.clearLogs()
                        viewModel.refreshLogs()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appRed)
                }
                
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(viewModel.logs.isEmpty ? "Логи отсутствуют" : viewModel.logs)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
                .padding(10)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
        }
    }
}

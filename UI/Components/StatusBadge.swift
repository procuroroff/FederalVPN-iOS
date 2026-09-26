import SwiftUI

public struct StatusBadge: View {
    let status: ConnectionStatus
    
    public init(status: ConnectionStatus) {
        self.status = status
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.8), radius: 4)
            
            Text(status.localizedTitle)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.appSurfaceElevated)
                .overlay(
                    Capsule()
                        .stroke(statusColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .disconnected: return Color.appTextMuted
        case .connecting:   return Color.appYellow
        case .connected:    return Color.appGreen
        case .disconnecting: return Color.appYellow
        case .error:        return Color.appRed
        }
    }
}

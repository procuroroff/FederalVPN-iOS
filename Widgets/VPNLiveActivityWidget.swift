import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit

@main
struct FederalVPNWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            VPNLiveActivityWidget()
        }
    }
}

@available(iOS 16.1, *)
struct VPNLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VPNActivityAttributes.self) { context in
            // Lock Screen / Notification Center banner
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.80, blue: 0.45).opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(context.state.serverFlag.isEmpty ? "🛡️" : context.state.serverFlag)
                        .font(.system(size: 22))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(context.state.serverName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Circle()
                            .fill(Color(red: 0.15, green: 0.80, blue: 0.45))
                            .frame(width: 7, height: 7)
                    }
                    
                    Text(context.state.serverCountry)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(timerInterval: context.state.connectedDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.15, green: 0.80, blue: 0.45))
                    
                    Text("ЗАЩИЩЕНО")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(white: 0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(context.state.serverFlag.isEmpty ? "🛡️" : context.state.serverFlag)
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.serverName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(context.state.serverCountry)
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.7))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(timerInterval: context.state.connectedDate...Date.distantFuture, countsDown: false)
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.15, green: 0.80, blue: 0.45))
                        Text("FEDERAL VPN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.15, green: 0.80, blue: 0.45))
                        Text("Трафик зашифрован • VLESS REALITY")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.7))
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Text(context.state.serverFlag.isEmpty ? "🛡️" : context.state.serverFlag)
                        .font(.system(size: 12))
                    Image(systemName: "shield.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.15, green: 0.80, blue: 0.45))
                }
            } compactTrailing: {
                Text(timerInterval: context.state.connectedDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.15, green: 0.80, blue: 0.45))
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.15, green: 0.80, blue: 0.45))
            }
        }
    }
}
#endif

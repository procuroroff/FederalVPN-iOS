import SwiftUI

/// Карточка с эффектом «жидкого стекла» (Liquid Glass) и адаптивным fallback для всех поколений iOS
public struct GlassCard<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let showRedBorder: Bool
    
    public init(
        cornerRadius: CGFloat = 18,
        padding: CGFloat = 16,
        showRedBorder: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showRedBorder = showRedBorder
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(
                glassBackground
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        showRedBorder ? Color.appRed.opacity(0.5) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 15.0, *) {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                LinearGradient.appGlassGradient
            }
        } else {
            // Fallback для более старых систем
            Color.appSurface.opacity(0.75)
        }
    }
}

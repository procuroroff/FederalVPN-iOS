import SwiftUI

/// Премиальная карточка «Жидкое стекло» (Liquid Glass) с реалистичным бликом, тонкой гранью и глубиной
public struct GlassCard<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let showRedBorder: Bool
    
    public init(
        cornerRadius: CGFloat = 20,
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
                liquidGlassBackground
            )
            .overlay(
                specularBorder
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 7)
            .shadow(color: showRedBorder ? Color.appRed.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
    }
    
    @ViewBuilder
    private var liquidGlassBackground: some View {
        if #available(iOS 15.0, *) {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Внутреннее свечение стеклянной подложки
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color.appSurface.opacity(0.85)
        }
    }
    
    private var specularBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                showRedBorder
                    ? LinearGradient(
                        colors: [Color.appRed, Color.appRedDark.opacity(0.6), Color.appRed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                lineWidth: showRedBorder ? 1.5 : 1.0
            )
    }
}

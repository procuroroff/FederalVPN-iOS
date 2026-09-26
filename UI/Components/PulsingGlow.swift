import SwiftUI

/// Легковесная пульсирующая анимация свечения вокруг центральной кнопки
public struct PulsingGlow: View {
    let isActive: Bool
    let color: Color
    
    @State private var isAnimating: Bool = false
    
    public init(isActive: Bool, color: Color = .appRed) {
        self.isActive = isActive
        self.color = color
    }
    
    public var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 3)
                    .scaleEffect(isAnimating ? 1.25 : 1.0)
                    .opacity(isAnimating ? 0.0 : 0.8)
                    .animation(
                        Animation.easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                Circle()
                    .fill(color.opacity(0.15))
                    .scaleEffect(isAnimating ? 1.15 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            if isActive {
                isAnimating = true
            }
        }
        .onChange(of: isActive) { active in
            isAnimating = active
        }
    }
}

import SwiftUI
import UIKit

enum TanjjetTheme {
    static let accent = Color(red: 0.97, green: 0.22, blue: 0.45)
    static let accentDeep = Color(red: 0.72, green: 0.12, blue: 0.32)
    static let mint = Color(red: 0.47, green: 0.78, blue: 0.72)
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.16)
    
    static var screenBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 1.00, green: 0.96, blue: 0.97),
                Color(red: 0.95, green: 0.99, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

struct TanjjetPrimaryButtonStyle: ButtonStyle {
    var isDisabled = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isDisabled ? AnyShapeStyle(Color(.systemGray4)) : AnyShapeStyle(TanjjetTheme.accentGradient))
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed && !isDisabled ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct TanjjetSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

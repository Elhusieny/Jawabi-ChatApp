
// Color+App.swift
import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let jawabiPrimary = Color(hex: "#5959a8")
    static let jawabiPrimaryLight = Color(hex: "#5959a8").opacity(0.2)
    static let jawabiPrimaryDark = Color(hex: "#5959a8").opacity(0.8)
    static let jawabiPrimaryOpacity = Color(hex: "#5959a8").opacity(0.5)
    
    // MARK: - Secondary Colors
    static let jawabiSecondary = Color(hex: "#7373d2")
    static let jawabiAccent = Color(hex: "#9d73d2")
    
    // MARK: - Background Gradients
    static let jawabiBackgroundGradient = LinearGradient(
        colors: [
            Color(hex: "#5959a8").opacity(0.1),
            Color(hex: "#5959a8").opacity(0.05),
            Color(hex: "#5959a8").opacity(0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let jawabiBackgroundGradientReversed = LinearGradient(
        colors: [
            Color(hex: "#5959a8").opacity(0.08),
            Color(hex: "#5959a8").opacity(0.05),
            Color(hex: "#5959a8").opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Button Gradients
    static let jawabiButtonGradient = LinearGradient(
        colors: [
            Color(hex: "#5959a8"),
            Color(hex: "#5959a8").opacity(0.8)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Status Colors
    static let jawabiOnline = Color(hex: "#25D366") // WhatsApp green
    static let jawabiError = Color.orange
    static let jawabiSuccess = Color.green
    
    // MARK: - Helper for hex initialization
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
// ViewModifiers.swift
import SwiftUI

// MARK: - Primary Button Style
struct JawabiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.jawabiPrimary)
            .cornerRadius(12)
            .shadow(color: Color.jawabiPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

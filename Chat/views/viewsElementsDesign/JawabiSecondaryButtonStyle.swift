
// MARK: - Secondary Button Style (Outlined)
struct JawabiSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.jawabiPrimary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.jawabiPrimary, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - TextField Style
struct JawabiTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.jawabiPrimary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - View Extensions for Easy Usage
extension View {
    func jawabiPrimaryButton() -> some View {
        self.buttonStyle(JawabiPrimaryButtonStyle())
    }
    
    func jawabiSecondaryButton() -> some View {
        self.buttonStyle(JawabiSecondaryButtonStyle())
    }
    
    func jawabiTextField() -> some View {
        self.textFieldStyle(JawabiTextFieldStyle())
    }
    
    func jawabiCardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.jawabiPrimary.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Gradient Background Modifier
struct JawabiGradientBackground: ViewModifier {
    @State private var animate = false
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if animate {
                        Color.jawabiBackgroundGradient
                    } else {
                        Color.jawabiBackgroundGradientReversed
                    }
                }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
    }
}

extension View {
    func jawabiGradientBackground() -> some View {
        modifier(JawabiGradientBackground())
    }
}

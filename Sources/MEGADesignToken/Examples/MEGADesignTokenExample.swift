private struct MEGADesignTokenExample {
    init() {
        // Example usage of five available generated enums
        let uiKitColorExample = TokenColors.Background.blur // UIColor
        let swiftUIColorExample = TokenColors.Button.brandPressed.swiftUI // Color
        let spacingExample = TokenSpacing._1 // CGFloat
        let radiusExample = TokenRadius.small // CGFloat
        let nsKitColorExample = TokenColors.Background.surface1 // NSColor

        print(String(describing: uiKitColorExample))
        print(String(describing: swiftUIColorExample))
        print(String(describing: spacingExample))
        print(String(describing: radiusExample))
        print(String(describing: nsKitColorExample))
    }
}

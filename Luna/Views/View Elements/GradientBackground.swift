//
//  GradientBackground.swift
//  Luna
//
//  Gradient background for Settings screens
//

import SwiftUI

// MARK: - Scroll Offset Tracking

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SettingsGradientBackground: View {
    @ObservedObject private var theme = LunaTheme.shared
    var scrollOffset: CGFloat = 0
    
    // Shift the gradient center downward as the user scrolls
    private var shift: CGFloat {
        min(max(scrollOffset, 0) / 1200, 0.55)
    }
    
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: theme.backgroundBase, location: max(0, shift - 0.05)),
                .init(color: theme.settingsGradientColor.opacity(0.6), location: shift),
                .init(color: theme.settingsGradientColor.opacity(0.3), location: min(shift + 0.2, 0.95)),
                .init(color: theme.backgroundBase, location: min(shift + 0.5, 1.0))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct GlobalGradientBackground: View {
    @ObservedObject private var theme = LunaTheme.shared
    var overrideColor: Color? = nil
    var scrollOffset: CGFloat = 0
    
    private var gradientColor: Color {
        overrideColor ?? theme.globalGradientColor
    }
    
    private var shift: CGFloat {
        min(max(scrollOffset, 0) / 1500, 0.4)
    }
    
    var body: some View {
        if theme.globalGradientEnabled || overrideColor != nil {
            LinearGradient(
                stops: [
                    .init(color: theme.backgroundBase, location: max(0, shift - 0.03)),
                    .init(color: gradientColor.opacity(0.7), location: shift),
                    .init(color: gradientColor.opacity(0.4), location: min(shift + 0.15, 0.8)),
                    .init(color: theme.backgroundBase, location: min(shift + 0.4, 1.0))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            theme.backgroundBase
        }
    }
}

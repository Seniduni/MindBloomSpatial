import SwiftUI
import UIKit

/// MIND BLOOM palette for visionOS. The same hues as the iOS app, slightly
/// brighter because glass windows and passthrough sit behind them.
enum SpatialTheme {
    static let teal = UIColor(red: 0.30, green: 0.78, blue: 0.71, alpha: 1)
    static let mint = UIColor(red: 0.50, green: 0.83, blue: 0.74, alpha: 1)
    static let lavender = UIColor(red: 0.71, green: 0.65, blue: 0.95, alpha: 1)
    static let sky = UIColor(red: 0.55, green: 0.74, blue: 0.94, alpha: 1)
    static let sun = UIColor(red: 0.94, green: 0.76, blue: 0.42, alpha: 1)
    static let peach = UIColor(red: 0.95, green: 0.66, blue: 0.56, alpha: 1)
    static let soil = UIColor(red: 0.27, green: 0.23, blue: 0.20, alpha: 1)
    static let stem = UIColor(red: 0.36, green: 0.62, blue: 0.45, alpha: 1)

    static let gradient = LinearGradient(colors: [Color(uiColor: teal), Color(uiColor: lavender)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Emotion {
    var uiColor: UIColor {
        switch valence {
        case 2: SpatialTheme.teal
        case 1: SpatialTheme.mint
        case 0: SpatialTheme.sun
        case -1: SpatialTheme.sky
        default: SpatialTheme.lavender
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension PlantColor {
    var uiColor: UIColor {
        switch self {
        case .teal: SpatialTheme.teal
        case .mint: SpatialTheme.mint
        case .lavender: SpatialTheme.lavender
        case .sky: SpatialTheme.sky
        case .sun: SpatialTheme.sun
        case .peach: SpatialTheme.peach
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

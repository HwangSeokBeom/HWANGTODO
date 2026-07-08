import HWANGTODOCore
import SwiftUI
import UIKit

/// Adaptive semantic colors, defined in code so the widget extension and Live
/// Activity render identically to the app in both light and dark mode.
public extension Color {
    /// Brand accent — calm indigo; the only saturated color used freely.
    static let hwangAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.49, green: 0.55, blue: 1.00, alpha: 1)
            : UIColor(red: 0.29, green: 0.34, blue: 0.87, alpha: 1)
    })
}

public extension Quadrant {
    /// Subtle, desaturated accents — dark-mode aware.
    var accent: Color {
        switch self {
        case .urgentImportant:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.95, green: 0.45, blue: 0.40, alpha: 1)
                    : UIColor(red: 0.83, green: 0.30, blue: 0.26, alpha: 1)
            })
        case .importantNotUrgent:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.45, green: 0.62, blue: 0.98, alpha: 1)
                    : UIColor(red: 0.25, green: 0.44, blue: 0.80, alpha: 1)
            })
        case .urgentNotImportant:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.93, green: 0.72, blue: 0.35, alpha: 1)
                    : UIColor(red: 0.76, green: 0.53, blue: 0.18, alpha: 1)
            })
        case .notUrgentNotImportant:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.62, green: 0.65, blue: 0.70, alpha: 1)
                    : UIColor(red: 0.44, green: 0.47, blue: 0.52, alpha: 1)
            })
        case .unassigned:
            .secondary
        }
    }
}

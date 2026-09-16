import SwiftUI

/// Grammar Llama's palette. Warm and vibrant, taken from the app icon.
enum Theme {
    static let coral = Color(red: 0.94, green: 0.33, blue: 0.27)      // #F0543F
    static let mango = Color(red: 0.98, green: 0.63, blue: 0.25)      // #FAA040
    static let cream = Color(red: 1.00, green: 0.96, blue: 0.92)      // #FFF6EC
    static let accent = coral
    static let gradient = LinearGradient(colors: [mango, coral], startPoint: .topLeading, endPoint: .bottomTrailing)
}

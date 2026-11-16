import SwiftUI

enum Theme {
    static let background = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.09, green: 0.11, blue: 0.10, alpha: 1)
        : UIColor(red: 0.97, green: 0.96, blue: 0.95, alpha: 1) })
    static let accent = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.63, green: 0.73, blue: 0.66, alpha: 1)
        : UIColor(red: 0.32, green: 0.42, blue: 0.35, alpha: 1) })
    static let onAccent = Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

struct WordPhoto: View {
    let data: Data

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
        }
    }
}

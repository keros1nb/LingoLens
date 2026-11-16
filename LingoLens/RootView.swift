import SwiftUI

struct RootView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { CameraView() }
                .tabItem { Label("Камера", systemImage: "camera") }
                .tag(0)
            NavigationStack { DictionaryView { selectedTab = 0 } }
                .tabItem { Label("Мой словарь", systemImage: "books.vertical") }
                .tag(1)
        }
        .tint(Theme.accent)
    }
}

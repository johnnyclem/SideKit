import SwiftUI

@main
struct SideKitApp: App {
    @StateObject private var store = MixerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}

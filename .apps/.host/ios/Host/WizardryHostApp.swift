import SwiftUI

@main
struct WizardryHostApp: App {
    var body: some Scene {
        WindowGroup {
            WizardryWebView()
                .ignoresSafeArea()
        }
    }
}

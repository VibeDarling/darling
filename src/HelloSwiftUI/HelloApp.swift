import SwiftUI

@main
struct HelloApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Hello, world!")
                .font(.largeTitle)
            Text("Tapped \(taps) times")
            Button("Tap me") {
                taps += 1
            }
        }
        .padding()
    }
}

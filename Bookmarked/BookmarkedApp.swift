import SwiftUI
import SwiftData

@main
struct BookmarkedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Book.self)
    }
}

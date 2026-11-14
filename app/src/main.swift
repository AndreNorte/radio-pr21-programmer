import SwiftUI

@main
struct PR21ManagerApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var store = ProfileStore()

    var body: some Scene {
        WindowGroup("PR-21 Manager") {
            ContentView()
                .environmentObject(model)
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 620)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Прочитать рацию") { model.connectAndRead() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Записать в рацию") { model.writeToRadio() }
                    .keyboardShortcut("w", modifiers: [.command])
                    .disabled(model.image == nil)
            }
        }
    }
}

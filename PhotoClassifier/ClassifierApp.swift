import SwiftUI

@main
struct ClassifierApp: App {
    @StateObject private var viewModel = ClassifierViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开文件夹...") {
                    viewModel.openFolder()
                }
                .keyboardShortcut("o")
            }
            CommandGroup(after: .pasteboard) {
                Button("全选") { viewModel.selectAll() }
                    .keyboardShortcut("a")
                Button("取消选择") { viewModel.deselectAll() }
                    .keyboardShortcut("d")
            }
        }
    }
}

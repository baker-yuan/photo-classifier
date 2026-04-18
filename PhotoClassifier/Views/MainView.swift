import SwiftUI

struct MainView: View {
    @EnvironmentObject var vm: ClassifierViewModel
    @State private var showAddTag = false
    @State private var newTagText = ""

    var body: some View {
        Group {
            if vm.currentDirectory == nil {
                WelcomeView()
            } else {
                mainContent
            }
        }
        .onChange(of: vm.viewMode) { newMode in
            if newMode == .detail {
                FullScreenDetailWindow.shared.show(vm: vm)
            } else {
                FullScreenDetailWindow.shared.close()
            }
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            SidebarView(showAddTag: $showAddTag, newTagText: $newTagText)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                GridToolbar()
                Divider()
                PhotoGridView()
                if !vm.selectedPhotos.isEmpty {
                    Divider()
                    TaggingBar()
                }
                Divider()
                StatusBar()
            }
        }
    }
}

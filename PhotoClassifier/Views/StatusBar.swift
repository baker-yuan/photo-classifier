import SwiftUI

struct StatusBar: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        HStack {
            if vm.isMoving {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
            Text(vm.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !vm.photos.isEmpty {
                Text("单击选中 | 双击沉浸浏览 | ⌘+点击多选 | 右键快速归类")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

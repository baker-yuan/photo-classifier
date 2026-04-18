import SwiftUI

struct TaggingBar: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text("已选 \(vm.selectedPhotos.count) 张")
                .font(.callout)
                .fontWeight(.medium)
            Divider().frame(height: 20)
            Text("移动到:")
                .font(.callout)
                .foregroundStyle(.secondary)

            tagButtons
            moveToRootButton

            Spacer()

            Button("取消选择") { vm.deselectAll() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("取消所有选择")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06))
    }

    private var tagButtons: some View {
        ForEach(Array(vm.availableTags.enumerated()), id: \.offset) { idx, tag in
            QuickTagButton(tag: tag, index: idx)
        }
    }

    private var moveToRootButton: some View {
        Button(action: { vm.moveSelectedToRoot() }) {
            Label("移回根目录", systemImage: "arrow.uturn.backward.circle")
        }
        .buttonStyle(.bordered)
        .tint(.gray)
        .help("将选中照片移回根目录")
    }
}

struct QuickTagButton: View {
    @EnvironmentObject var vm: ClassifierViewModel
    let tag: String
    let index: Int

    var body: some View {
        Button(action: { vm.moveSelectedToTag(tag) }) {
            Label(tag, systemImage: tagIcon)
        }
        .buttonStyle(.bordered)
        .tint(tagColor)
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        .help("移动到「\(tag)」（⌘\(index + 1)）")
    }

    private var tagIcon: String {
        switch tag {
        case "保留": return "checkmark.circle.fill"
        case "删除": return "trash.circle.fill"
        default: return "folder.circle.fill"
        }
    }

    private var tagColor: Color {
        deterministicTagColor(tag)
    }
}

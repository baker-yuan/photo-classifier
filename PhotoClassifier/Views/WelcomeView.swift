import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var vm: ClassifierViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("图片整理")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("快速标注与整理你的照片")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button(action: { vm.openFolder() }) {
                Label("选择文件夹", systemImage: "folder")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !vm.recentDirectories.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近打开")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(vm.recentDirectories, id: \.path) { url in
                        HStack(spacing: 8) {
                            Button(action: { vm.openRecent(url) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)

                            Text(url.deletingLastPathComponent().path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.head)

                            Spacer()

                            Button(action: { vm.removeFromRecent(url) }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
                .frame(width: 360)
            }

            VStack(spacing: 6) {
                Text("⌘O 打开文件夹")
                Text("子目录自动识别为标签归类")
                Text("双击照片进入沉浸式打标")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

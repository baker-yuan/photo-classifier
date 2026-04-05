import SwiftUI
import AppKit
import AVKit

// MARK: - Full-screen Immersive Detail View

struct PhotoDetailView: View {
    @EnvironmentObject var vm: ClassifierViewModel
    @State private var fullImage: NSImage?
    @State private var player: AVPlayer?
    @State private var showControls = true
    @State private var controlTimer: Timer?

    var body: some View {
        ZStack {
            Color.black

            mediaContent

            navigationOverlay

            VStack(spacing: 0) {
                if showControls {
                    topBar
                }
                Spacer()
                if showControls {
                    bottomBar
                }
            }

            // Toast overlay — prominent visual feedback after tagging
            toastOverlay
        }
        .onAppear { loadMedia() }
        // Watch the actual photo identity, not just the index.
        // This correctly reloads media when:
        //  - User navigates (detailIndex changes → different photo id)
        //  - Photo drops out of filtered list after tagging (same index → different photo id)
        .onChange(of: vm.currentDetailPhoto?.id) { _ in loadMedia() }
        .onReceive(NotificationCenter.default.publisher(for: .detailKeyEvent)) { note in
            if let key = note.object as? String { handleKey(key) }
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = vm.detailToast {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text(toast)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(toastColor(toast).opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                .padding(.bottom, 90)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.detailToast)
        }
    }

    private func toastColor(_ label: String) -> Color {
        switch label {
        case "保留": return .green
        case "删除": return .red
        case "根目录": return .gray
        default: return .blue
        }
    }

    // MARK: - Media Content

    @ViewBuilder
    private var mediaContent: some View {
        if let photo = vm.currentDetailPhoto, photo.isVideo {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
            } else {
                ProgressView()
                    .tint(.white)
            }
        } else if let img = fullImage {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    // MARK: - Navigation Arrows

    private var navigationOverlay: some View {
        HStack(spacing: 0) {
            Button(action: { vm.previousPhoto(); resetControlTimer() }) {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80)
                    .contentShape(Rectangle())
                    .overlay(alignment: .center) {
                        if showControls && vm.detailIndex > 0 {
                            navArrow(systemName: "chevron.left")
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(vm.detailIndex <= 0)

            Spacer()

            Button(action: { vm.nextPhoto(); resetControlTimer() }) {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80)
                    .contentShape(Rectangle())
                    .overlay(alignment: .center) {
                        if showControls && vm.detailIndex < vm.filteredPhotos.count - 1 {
                            navArrow(systemName: "chevron.right")
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(vm.detailIndex >= vm.filteredPhotos.count - 1)
        }
        .frame(maxHeight: .infinity)
    }

    private func navArrow(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .padding(12)
            .background(.black.opacity(0.4))
            .clipShape(Circle())
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: { closeDetail() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            if let photo = vm.currentDetailPhoto {
                Text(photo.fileName)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if photo.isVideo {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            currentTagBadge
                .animation(.easeInOut(duration: 0.2), value: vm.currentDetailPhoto?.tag)

            Text("\(vm.detailIndex + 1) / \(vm.filteredPhotos.count)")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [.black.opacity(0.6), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder
    private var currentTagBadge: some View {
        if let photo = vm.currentDetailPhoto {
            if let tag = photo.tag {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text(tag)
                }
                .font(.callout)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(tagColor(tag).opacity(0.85))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12))
                    Text("未分类")
                }
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15))
                .foregroundStyle(.white.opacity(0.6))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text("移动到:")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))

            tagButtonsRow

            Divider()
                .frame(height: 24)
                .overlay(Color.white.opacity(0.2))

            moveToRootBtn

            Spacer()

            Text("← → 切换  ⌘+数字 分类  ESC 退出")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var tagButtonsRow: some View {
        ForEach(Array(vm.availableTags.enumerated()), id: \.offset) { idx, tag in
            ImmersiveTagButton(tag: tag, index: idx)
        }
    }

    private var moveToRootBtn: some View {
        Button(action: {
            guard let photo = vm.currentDetailPhoto, photo.tag != nil else { return }
            vm.moveCurrentDetailToRoot()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                Text("根目录")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(vm.currentDetailPhoto?.tag == nil)
        .opacity(vm.currentDetailPhoto?.tag == nil ? 0.3 : 1)
    }

    // MARK: - Key Handling

    private func handleKey(_ key: String) {
        resetControlTimer()
        switch key {
        case "left": vm.previousPhoto()
        case "right": vm.nextPhoto()
        case "escape": closeDetail()
        case "space": toggleControls()
        default:
            if let num = Int(key), num >= 1, num <= vm.availableTags.count {
                let tag = vm.availableTags[num - 1]
                vm.tagCurrentDetail(tag)
            }
        }
    }

    private func closeDetail() {
        player?.pause()
        player = nil
        controlTimer?.invalidate()
        vm.closeDetail()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
    }

    private func resetControlTimer() {
        showControls = true
        controlTimer?.invalidate()
    }

    // MARK: - Helpers

    private func loadMedia() {
        fullImage = nil
        player?.pause()
        player = nil
        guard let photo = vm.currentDetailPhoto else { return }

        if photo.isVideo {
            player = AVPlayer(url: photo.url)
        } else {
            let url = photo.url
            DispatchQueue.global(qos: .userInitiated).async {
                let img = NSImage(contentsOf: url)
                DispatchQueue.main.async { fullImage = img }
            }
        }
    }

    private func tagColor(_ t: String) -> Color {
        switch t {
        case "保留": return .green
        case "删除": return .red
        default:
            let colors: [Color] = [.blue, .purple, .orange, .teal, .indigo, .pink]
            return colors[abs(t.hashValue) % colors.count]
        }
    }
}

// MARK: - Immersive Tag Button

struct ImmersiveTagButton: View {
    @EnvironmentObject var vm: ClassifierViewModel
    let tag: String
    let index: Int

    private var isCurrent: Bool {
        vm.currentDetailPhoto?.tag == tag
    }

    var body: some View {
        Button(action: {
            vm.tagCurrentDetail(tag)
        }) {
            HStack(spacing: 6) {
                Image(systemName: isCurrent ? "checkmark.circle.fill" : tagIcon)
                Text(tag)
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isCurrent ? btnColor.opacity(0.7) : .white.opacity(0.15))
            .overlay {
                if isCurrent {
                    Capsule().stroke(btnColor, lineWidth: 2)
                }
            }
            .clipShape(Capsule())
            .scaleEffect(isCurrent ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isCurrent)
        }
        .buttonStyle(.plain)
    }

    private var tagIcon: String {
        switch tag {
        case "保留": return "checkmark.circle"
        case "删除": return "trash.circle"
        default: return "folder.circle"
        }
    }

    private var btnColor: Color {
        switch tag {
        case "保留": return .green
        case "删除": return .red
        default:
            let colors: [Color] = [.blue, .purple, .orange, .teal, .indigo, .pink]
            return colors[abs(tag.hashValue) % colors.count]
        }
    }
}

// MARK: - Full-Screen Window Manager

extension Notification.Name {
    static let detailKeyEvent = Notification.Name("detailKeyEvent")
}

final class FullScreenDetailWindow {
    static let shared = FullScreenDetailWindow()
    private var window: NSWindow?
    private var eventMonitor: Any?
    private init() {}

    func show(vm: ClassifierViewModel) {
        close()

        guard let screen = NSApp.keyWindow?.screen ?? NSScreen.main else { return }

        let win = _FullScreenPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.setFrame(screen.frame, display: true)
        win.backgroundColor = .black
        win.isOpaque = true
        win.hasShadow = false
        win.level = .normal

        let hosting = NSHostingView(
            rootView: PhotoDetailView()
                .environmentObject(vm)
        )
        win.contentView = hosting
        win.makeKeyAndOrderFront(nil)

        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        // Intercept ⌘+number BEFORE the menu system handles it.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.window?.isKeyWindow == true else { return event }
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers, chars.count == 1,
               let num = chars.first?.wholeNumberValue, num >= 1, num <= 9 {
                NotificationCenter.default.post(name: .detailKeyEvent, object: "\(num)")
                return nil // consumed
            }
            return event
        }

        self.window = win
    }

    func close() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        NSApp.presentationOptions = []
    }
}

private class _FullScreenPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        let key: String?
        switch event.keyCode {
        case 123: key = "left"
        case 124: key = "right"
        case 53:  key = "escape"
        case 49:  key = "space"
        default:  key = nil
        }
        if let key = key {
            NotificationCenter.default.post(name: .detailKeyEvent, object: key)
        }
    }
}

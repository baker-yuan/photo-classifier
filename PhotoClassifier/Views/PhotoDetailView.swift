import SwiftUI
import AppKit
import AVKit

// MARK: - Full-screen Immersive Detail View

struct PhotoDetailView: View {
    @EnvironmentObject var vm: ClassifierViewModel
    @State private var fullImage: NSImage?
    @State private var player: AVPlayer?
    @State private var showControls = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying: Bool = true
    @State private var isSeeking: Bool = false
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?
    @State private var exifInfo: ExifInfo?
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black

            mediaContent
                .scaleEffect(zoomScale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomScale = min(max(lastZoomScale * value, 1.0), 10.0)
                        }
                        .onEnded { _ in
                            if zoomScale < 1.05 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    zoomScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                                lastZoomScale = 1.0
                            } else {
                                lastZoomScale = zoomScale
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard zoomScale > 1.0 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            guard zoomScale > 1.0 else { return }
                            lastOffset = offset
                        }
                )

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

            toastOverlay
        }
        .onAppear { loadMedia() }
        .onDisappear { cleanupPlayer() }
        .onChange(of: vm.currentDetailPhoto?.id) { _ in loadMedia() }
        .onReceive(NotificationCenter.default.publisher(for: .detailKeyEvent)) { note in
            if let key = note.object as? String { handleKey(key) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .detailScrollEvent)) { note in
            if let info = note.userInfo,
               let delta = info["delta"] as? CGFloat,
               let precise = info["precise"] as? Bool {
                handleScrollZoom(delta: delta, precise: precise)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .detailDoubleClick)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                if zoomScale > 1.0 {
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    zoomScale = 3.0
                    lastZoomScale = 3.0
                }
            }
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
                PlayerView(player: player)
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
                        if showControls && vm.filteredPhotos.count > 1 && vm.detailIndex < vm.filteredPhotos.count - 1 {
                            navArrow(systemName: "chevron.right")
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(vm.filteredPhotos.count <= 1 || vm.detailIndex >= vm.filteredPhotos.count - 1)
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
                    Text("未归类")
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
        VStack(spacing: 8) {
            if vm.currentDetailPhoto?.isVideo == true {
                videoProgressBar
            }
            if let exif = exifInfo, vm.currentDetailPhoto?.isVideo != true {
                exifBar(exif)
            }
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

                Text("← → 切换  双击放大  +/- 缩放  ⌘+数字 归类  ESC 退出")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
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

    private func exifBar(_ exif: ExifInfo) -> some View {
        HStack(spacing: 16) {
            if let camera = exif.cameraDisplay {
                exifChip(icon: "camera", text: camera)
            }
            if let lens = exif.lensModel {
                exifChip(icon: "camera.metering.spot", text: lens)
            }
            if let fl = exif.focalLengthDisplay {
                exifChip(icon: "scope", text: fl)
            }
            if let ap = exif.apertureDisplay {
                exifChip(icon: "circle.circle", text: ap)
            }
            if let ss = exif.shutterDisplay {
                exifChip(icon: "timer", text: ss)
            }
            if let iso = exif.isoDisplay {
                exifChip(icon: "sun.max", text: iso)
            }
            if let res = exif.resolutionDisplay {
                exifChip(icon: "rectangle.split.3x3", text: res)
            }
            if let date = exif.dateTaken {
                exifChip(icon: "calendar", text: date)
            }
            Spacer()
        }
    }

    private func exifChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.6))
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

    // MARK: - Video Progress Bar

    private var videoProgressBar: some View {
        HStack(spacing: 10) {
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Text(formatTime(currentTime))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 45, alignment: .trailing)

            Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                isSeeking = editing
                if editing {
                    player?.pause()
                } else {
                    player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600),
                                 toleranceBefore: .zero, toleranceAfter: .zero)
                    if isPlaying { player?.play() }
                }
            }
            .tint(.white)

            Text(formatTime(duration))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 45, alignment: .leading)
        }
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Key Handling

    private func handleKey(_ key: String) {
        resetControlTimer()
        switch key {
        case "left": vm.previousPhoto()
        case "right": vm.nextPhoto()
        case "escape": closeDetail()
        case "space": toggleControls()
        case "zoomIn":
            withAnimation(.easeOut(duration: 0.15)) {
                zoomScale = min(zoomScale * 1.5, 10.0)
                lastZoomScale = zoomScale
            }
        case "zoomOut":
            withAnimation(.easeOut(duration: 0.15)) {
                let newScale = zoomScale / 1.5
                if newScale <= 1.05 {
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    zoomScale = newScale
                    lastZoomScale = newScale
                }
            }
        case "zoomReset":
            withAnimation(.easeOut(duration: 0.15)) {
                zoomScale = 1.0
                lastZoomScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        default:
            if let num = Int(key), num >= 1, num <= vm.availableTags.count {
                let tag = vm.availableTags[num - 1]
                vm.tagCurrentDetail(tag)
            }
        }
    }

    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func closeDetail() {
        cleanupPlayer()
        vm.closeDetail()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
    }

    private func resetControlTimer() {
        showControls = true
    }

    private func handleScrollZoom(delta: CGFloat, precise: Bool) {
        let adjustedDelta = precise ? -delta : delta
        let sensitivity: CGFloat = precise ? 0.005 : 0.03
        let factor = 1.0 + adjustedDelta * sensitivity
        let newScale = min(max(zoomScale * factor, 1.0), 10.0)

        if newScale <= 1.02 {
            withAnimation(.easeOut(duration: 0.15)) {
                zoomScale = 1.0
                lastZoomScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        } else {
            zoomScale = newScale
            lastZoomScale = newScale
        }
    }

    // MARK: - Helpers

    private func loadMedia() {
        fullImage = nil
        exifInfo = nil
        cleanupPlayer()
        currentTime = 0
        duration = 0
        isPlaying = true
        zoomScale = 1.0
        lastZoomScale = 1.0
        offset = .zero
        lastOffset = .zero
        guard let photo = vm.currentDetailPhoto else { return }

        if photo.isVideo {
            let newPlayer = AVPlayer(url: photo.url)
            player = newPlayer

            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak newPlayer] time in
                guard !self.isSeeking else { return }
                self.currentTime = time.seconds
                if let item = newPlayer?.currentItem, item.status == .readyToPlay {
                    let dur = item.duration.seconds
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                }
            }

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                self.isPlaying = false
            }

            newPlayer.play()
        } else {
            let url = photo.url
            DispatchQueue.global(qos: .userInitiated).async {
                let img = NSImage(contentsOf: url)
                let exif = ExifInfo.read(from: url)
                DispatchQueue.main.async {
                    fullImage = img
                    exifInfo = exif
                }
            }
        }
    }

    private func tagColor(_ t: String) -> Color {
        deterministicTagColor(t)
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
        deterministicTagColor(tag)
    }
}

// MARK: - AVPlayerView Wrapper (AppKit)

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

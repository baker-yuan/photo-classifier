import SwiftUI

private let tagColorPalette: [Color] = [.blue, .purple, .orange, .teal, .indigo, .pink, .mint, .cyan]

func deterministicTagColor(_ tag: String) -> Color {
    switch tag {
    case "保留": return .green
    case "删除": return .red
    default:
        var hash: UInt64 = 5381
        for byte in tag.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return tagColorPalette[Int(hash % UInt64(tagColorPalette.count))]
    }
}

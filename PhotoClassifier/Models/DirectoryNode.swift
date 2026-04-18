import Foundation

struct DirectoryNode: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let name: String
    let children: [DirectoryNode]

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: DirectoryNode, rhs: DirectoryNode) -> Bool { lhs.url == rhs.url }
}

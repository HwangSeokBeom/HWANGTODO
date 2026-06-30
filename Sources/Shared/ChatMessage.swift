import Foundation

/// One line in the private "chat with myself" stream. Messages can be turned
/// into tasks; `convertedTaskIDs` records which tasks came from this message.
struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var createdAt: Date
    var convertedTaskIDs: [UUID]

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, convertedTaskIDs: [UUID] = []) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.convertedTaskIDs = convertedTaskIDs
    }

    var isConverted: Bool { !convertedTaskIDs.isEmpty }
}

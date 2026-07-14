import SwiftData

enum ModelContainerFactory {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: FamilyMember.self,
            ChoreRule.self,
            ChoreTask.self,
            CompletionRecord.self,
            configurations: configuration
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }
}

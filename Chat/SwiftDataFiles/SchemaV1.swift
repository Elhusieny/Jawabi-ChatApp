import SwiftData

// MARK: - Schema V1 (original shape)
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ChatEntity.self, MessageEntity.self, UserEntity.self, UserProfileEntityV1.self]
    }
}

extension SchemaV1 {
    @Model
    final class UserProfileEntityV1 {
        @Attribute(.unique) var userId: String
        var userName: String
        var displayName: String
        var email: String
        var phoneNumber: String
        var authToken: String
        var fcmToken: String?
        var savedAt: Date

        init(userId: String, userName: String, displayName: String, email: String,
             phoneNumber: String, authToken: String, fcmToken: String? = nil) {
            self.userId = userId
            self.userName = userName
            self.displayName = displayName
            self.email = email
            self.phoneNumber = phoneNumber
            self.authToken = authToken
            self.fcmToken = fcmToken
            self.savedAt = .now
        }
    }
}

// MARK: - Schema V2 (adds profilePictureUrl)
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ChatEntity.self, MessageEntity.self, UserEntity.self, UserProfileEntity.self]
    }
}

extension SchemaV2 {
    @Model
    final class UserProfileEntity {
        @Attribute(.unique) var userId: String
        var userName: String
        var displayName: String
        var email: String
        var phoneNumber: String
        var authToken: String
        var fcmToken: String?
        var profilePictureUrl: String = ""
        var savedAt: Date

        init(userId: String, userName: String, displayName: String, email: String,
             phoneNumber: String, authToken: String, fcmToken: String? = nil,
             profilePictureUrl: String = "") {
            self.userId = userId
            self.userName = userName
            self.displayName = displayName
            self.email = email
            self.phoneNumber = phoneNumber
            self.authToken = authToken
            self.fcmToken = fcmToken
            self.profilePictureUrl = profilePictureUrl
            self.savedAt = .now
        }
    }
}

// MARK: - Migration Plan
enum ChatMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}

// Point the rest of the app at the current version's types
typealias ChatEntity = SchemaV2.ChatEntity      // adjust if ChatEntity itself didn't change
typealias MessageEntity = SchemaV2.MessageEntity
typealias UserEntity = SchemaV2.UserEntity
typealias UserProfileEntity = SchemaV2.UserProfileEntity
import Foundation

public actor IdempotencyManager {
    private let defaultsKey = "com.yunochallengesdk.idempotency"
    private var submittedKeys: Set<UUID>

    public init() {
        if let data = UserDefaults.standard.data(forKey: "com.yunochallengesdk.idempotency"),
           let keys = try? JSONDecoder().decode([UUID].self, from: data) {
            submittedKeys = Set(keys)
        } else {
            submittedKeys = []
        }
    }

    public func hasBeenSubmitted(key: UUID) -> Bool {
        submittedKeys.contains(key)
    }

    public func markSubmitted(key: UUID) {
        submittedKeys.insert(key)
        let array = Array(submittedKeys)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

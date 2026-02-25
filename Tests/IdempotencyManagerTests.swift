// Coverage target: IdempotencyManager – 3 test cases
// Tests: mark+detect, key independence, parameterized multi-key isolation

import Testing
import Foundation
@testable import YunoChallengeSDK

@Suite("IdempotencyManager")
struct IdempotencyManagerTests {

    // MARK: Mark and detect

    @Test("marks key as submitted and detects duplicate")
    func markAndDetect() async throws {
        let manager = IdempotencyManager()
        let key = UUID()

        #expect(await manager.hasBeenSubmitted(key: key) == false)
        await manager.markSubmitted(key: key)
        #expect(await manager.hasBeenSubmitted(key: key) == true)
    }

    // MARK: Key independence

    @Test("different keys are independent")
    func independentKeys() async throws {
        let manager = IdempotencyManager()
        let key1 = UUID()
        let key2 = UUID()

        await manager.markSubmitted(key: key1)

        #expect(await manager.hasBeenSubmitted(key: key1) == true)
        #expect(await manager.hasBeenSubmitted(key: key2) == false)
    }

    // MARK: Parameterized — each key isolated in its own manager instance

    @Test("multiple keys can be marked independently", arguments: [UUID(), UUID(), UUID()])
    func multipleKeys(key: UUID) async throws {
        let manager = IdempotencyManager()
        #expect(await manager.hasBeenSubmitted(key: key) == false)
        await manager.markSubmitted(key: key)
        #expect(await manager.hasBeenSubmitted(key: key) == true)
    }
}

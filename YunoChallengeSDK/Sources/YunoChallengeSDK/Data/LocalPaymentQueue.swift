import Foundation

public actor LocalPaymentQueue: PaymentQueueProtocol {
    private let key = "com.yunochallengesdk.queue"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func enqueue(_ payment: Payment) async throws {
        var payments = try loadAll()
        payments.append(payment)
        try save(payments)
    }

    public func dequeueAll() async throws -> [Payment] {
        try loadAll()
    }

    public func update(_ payment: Payment) async throws {
        var payments = try loadAll()
        guard let index = payments.firstIndex(where: { $0.id == payment.id }) else { return }
        payments[index] = payment
        try save(payments)
    }

    public func remove(id: UUID) async throws {
        var payments = try loadAll()
        payments.removeAll { $0.id == id }
        try save(payments)
    }

    private func loadAll() throws -> [Payment] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([Payment].self, from: data)
    }

    private func save(_ payments: [Payment]) throws {
        let data = try JSONEncoder().encode(payments)
        defaults.set(data, forKey: key)
    }
}

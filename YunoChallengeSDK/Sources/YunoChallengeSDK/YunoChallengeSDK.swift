import Foundation
import Combine

@MainActor
public final class YunoChallengeSDK: ObservableObject {
    public static let shared = YunoChallengeSDK()
    @Published public private(set) var payments: [Payment] = []
    private var syncService: PaymentSyncService?

    private init() {}

    public func configure(
        queue: any PaymentQueueProtocol,
        api: any PaymentAPIProtocol,
        monitor: any NetworkMonitorProtocol
    ) {
        let service = PaymentSyncService(queue: queue, api: api, monitor: monitor)
        service.setOnPaymentsUpdated { [weak self] updated in
            Task { @MainActor [weak self] in
                self?.payments = updated
            }
        }
        self.syncService = service
        service.start()
    }

    public func submitPayment(_ request: PaymentRequest) async throws {
        guard let service = syncService else { throw SDKError.notConfigured }
        try await service.submit(request)
    }
}

public enum SDKError: Error, Sendable {
    case notConfigured
}

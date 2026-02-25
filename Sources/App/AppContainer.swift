import Foundation
import YunoChallengeSDK

@MainActor
final class AppContainer {
    let sdk: YunoChallengeSDK
    let networkMonitor: SystemNetworkMonitor

    init() {
        let monitor = SystemNetworkMonitor()
        self.networkMonitor = monitor
        self.sdk = YunoChallengeSDK.shared
        sdk.configure(
            queue: LocalPaymentQueue(),
            api: MockPaymentAPI(),
            monitor: monitor
        )
    }
}

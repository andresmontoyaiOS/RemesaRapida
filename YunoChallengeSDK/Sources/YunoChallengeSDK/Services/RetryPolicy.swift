import Foundation

public enum RetryDecision: Sendable {
    case retry(delay: TimeInterval)
    case permanentFailure
}

public struct RetryPolicy: Sendable {
    public static let maxAttempts = 3
    public static let baseDelay: TimeInterval = 1.0

    public static func decide(error: Error, attempt: Int) -> RetryDecision {
        guard attempt < maxAttempts else { return .permanentFailure }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .notConnectedToInternet, .networkConnectionLost, .badServerResponse:
                let delay = baseDelay * pow(2.0, Double(attempt))
                return .retry(delay: delay)
            default:
                return .permanentFailure
            }
        }
        return .permanentFailure
    }
}

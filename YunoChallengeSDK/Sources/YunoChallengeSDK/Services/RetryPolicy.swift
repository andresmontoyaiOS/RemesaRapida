import Foundation

/// The outcome of a single retry policy evaluation.
///
/// ``PaymentSyncService`` inspects the decision returned by ``RetryPolicy/decide(error:attempt:)``
/// after each failed API call to determine whether to wait and try again or to
/// permanently fail the payment.
///
/// ## Topics
/// ### Cases
/// - ``retry(delay:)``
/// - ``permanentFailure``
public enum RetryDecision: Sendable {
    /// The error is transient and the caller should retry after the given delay.
    ///
    /// - Parameter delay: The number of seconds to wait before the next attempt.
    ///   Computed using exponential backoff: `baseDelay * 2^attempt`.
    case retry(delay: TimeInterval)

    /// The error is not retryable, or the maximum attempt count has been reached.
    ///
    /// The payment should be marked ``PaymentStatus/failed`` immediately.
    case permanentFailure
}

/// A stateless policy that decides whether a failed payment submission should be
/// retried, and how long to wait before the next attempt.
///
/// `RetryPolicy` applies exponential backoff with a base delay of
/// ``baseDelay`` seconds for `URLError` codes that represent transient
/// infrastructure failures. Business-level errors (e.g. a non-`URLError`) and
/// attempts that reach ``maxAttempts`` always produce ``RetryDecision/permanentFailure``.
///
/// ## Retry-eligible error codes
/// - `URLError.timedOut`
/// - `URLError.notConnectedToInternet`
/// - `URLError.networkConnectionLost`
/// - `URLError.badServerResponse`
///
/// ## Delay formula
/// ```
/// delay = baseDelay * 2^attempt
/// ```
///
/// So for `baseDelay = 1.0`: attempt 0 → 1 s, attempt 1 → 2 s, attempt 2 → 4 s.
///
/// ## Example
/// ```swift
/// do {
///     let status = try await api.submit(payment)
/// } catch {
///     switch RetryPolicy.decide(error: error, attempt: currentAttempt) {
///     case .retry(let delay):
///         try await Task.sleep(for: .seconds(delay))
///     case .permanentFailure:
///         payment.status = .failed
///     }
/// }
/// ```
///
/// ## Topics
/// ### Related Types
/// - ``RetryDecision``
/// - ``PaymentSyncService``
public struct RetryPolicy: Sendable {

    // MARK: - Properties

    /// The maximum number of submission attempts before a payment is permanently failed.
    ///
    /// After `maxAttempts` attempts ``decide(error:attempt:)`` always returns
    /// ``RetryDecision/permanentFailure`` regardless of the error type.
    public static let maxAttempts = 3

    /// The base delay in seconds used for exponential backoff calculation.
    ///
    /// Delay for attempt `n` = `baseDelay * 2^n`.
    public static let baseDelay: TimeInterval = 1.0

    // MARK: - Public API

    /// Evaluates whether a failed submission should be retried or permanently failed.
    ///
    /// - Parameters:
    ///   - error: The error thrown by the payment API on the most recent attempt.
    ///   - attempt: The zero-indexed count of attempts already made. When
    ///     `attempt >= maxAttempts` the method returns ``RetryDecision/permanentFailure``
    ///     regardless of the error type.
    /// - Returns: A ``RetryDecision`` indicating whether to retry (with a computed
    ///   backoff delay) or to stop.
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

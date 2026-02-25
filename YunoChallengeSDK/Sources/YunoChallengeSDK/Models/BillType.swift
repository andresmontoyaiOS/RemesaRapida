import Foundation

/// Represents the category of a utility or service bill that can be paid through the SDK.
///
/// Each case maps directly to a string raw value used for JSON serialization and display.
/// The ``PaymentRequest`` uses `BillType` to classify payments before submission.
///
/// ## Topics
/// ### Bill Categories
/// - ``electricity``
/// - ``water``
/// - ``phone``
/// - ``internet``
public enum BillType: String, Codable, CaseIterable, Sendable {
    /// An electricity utility bill.
    case electricity
    /// A water utility bill.
    case water
    /// A phone service bill.
    case phone
    /// An internet service bill.
    case internet
}

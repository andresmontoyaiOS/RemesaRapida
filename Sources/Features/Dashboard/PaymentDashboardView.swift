import SwiftUI
import YunoChallengeSDK

/// The root view of the RemesaRapida app, displaying the payment history and
/// summary statistics.
///
/// `PaymentDashboardView` reads from `YunoChallengeSDK` via `@EnvironmentObject`
/// and delegates presentation logic to a lazily created `PaymentDashboardViewModel`.
/// The view model is created in `.onAppear` rather than at init time so that the
/// SDK environment object is available when the view model initializer runs.
///
/// ### Navigation
/// - Tapping the antenna toolbar button presents `NetworkSimulatorView` (modal sheet)
///   for toggling simulated offline/online states during development.
/// - Tapping "Pay Bill" presents `PaymentSubmissionView` (modal sheet) for submitting
///   a new bill payment.
///
/// ### Sub-views
/// - `PaymentRowView` — renders a single payment in the list.
/// - `StatusBadge` — renders a colored capsule label for a `PaymentStatus`.
struct PaymentDashboardView: View {

    // MARK: - Properties

    /// The SDK singleton that owns the live payment list.
    @EnvironmentObject private var sdk: YunoChallengeSDK

    /// The lazily initialized view model; `nil` until `.onAppear` fires.
    @State private var viewModel: PaymentDashboardViewModel?

    /// Controls presentation of the `PaymentSubmissionView` sheet.
    @State private var showingSubmission = false

    /// Controls presentation of the `NetworkSimulatorView` sheet.
    @State private var showingNetworkSim = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    dashboardContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("RemesaRápida")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingNetworkSim = true
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Pay Bill") { showingSubmission = true }
                }
            }
            .sheet(isPresented: $showingSubmission) {
                PaymentSubmissionView().environmentObject(sdk)
            }
            .sheet(isPresented: $showingNetworkSim) {
                NetworkSimulatorView()
            }
        }
        .onAppear {
            viewModel = PaymentDashboardViewModel(sdk: sdk)
        }
    }

    // MARK: - Private Helpers

    /// Builds the list-based content displayed when the view model is available.
    ///
    /// - Parameter vm: The fully initialized view model to read data from.
    @ViewBuilder
    private func dashboardContent(vm: PaymentDashboardViewModel) -> some View {
        List {
            Section {
                HStack {
                    Label("\(vm.pendingCount) pendiente(s)", systemImage: "clock")
                    Spacer()
                    Text("Aprobado: $\(vm.approvedTotal as NSDecimalNumber)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            Section("Pagos") {
                if vm.payments.isEmpty {
                    ContentUnavailableView(
                        "Sin pagos",
                        systemImage: "creditcard",
                        description: Text("Toca \"Pay Bill\" para enviar un pago.")
                    )
                } else {
                    ForEach(vm.payments) { payment in
                        PaymentRowView(payment: payment)
                    }
                }
            }
        }
    }
}

// MARK: - PaymentRowView

/// A list row that presents the summary of a single `Payment`.
///
/// Displays the bill type, reference number, amount, and a color-coded `StatusBadge`.
private struct PaymentRowView: View {

    // MARK: - Properties

    /// The payment whose details are rendered in this row.
    let payment: Payment

    // MARK: - Body

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.request.billType.rawValue.capitalized)
                    .font(.headline)
                Text(payment.request.billReference)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(payment.request.amount as NSDecimalNumber)")
                    .font(.subheadline)
                StatusBadge(status: payment.status)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - StatusBadge

/// A capsule-shaped label that renders a `PaymentStatus` with a semantic color.
///
/// | Status | Color |
/// |--------|-------|
/// | queued | gray |
/// | processing | blue |
/// | approved | green |
/// | declined | red |
/// | failed | orange |
private struct StatusBadge: View {

    // MARK: - Properties

    /// The payment lifecycle state to render.
    let status: PaymentStatus

    // MARK: - Body

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Private Helpers

    /// Returns the semantic color associated with the given payment status.
    private var color: Color {
        switch status {
        case .queued: .gray
        case .processing: .blue
        case .approved: .green
        case .declined: .red
        case .failed: .orange
        }
    }
}

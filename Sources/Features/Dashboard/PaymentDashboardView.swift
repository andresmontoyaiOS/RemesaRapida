import SwiftUI
import YunoChallengeSDK

struct PaymentDashboardView: View {
    @EnvironmentObject private var sdk: YunoChallengeSDK
    @State private var viewModel: PaymentDashboardViewModel?
    @State private var showingSubmission = false
    @State private var showingNetworkSim = false

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

private struct PaymentRowView: View {
    let payment: Payment

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

private struct StatusBadge: View {
    let status: PaymentStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

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

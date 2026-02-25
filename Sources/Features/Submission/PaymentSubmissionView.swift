import SwiftUI
import YunoChallengeSDK

struct PaymentSubmissionView: View {
    @EnvironmentObject private var sdk: YunoChallengeSDK
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PaymentSubmissionViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    formContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Pagar Servicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onAppear { viewModel = PaymentSubmissionViewModel(sdk: sdk) }
    }

    @ViewBuilder
    private func formContent(vm: PaymentSubmissionViewModel) -> some View {
        Form {
            Section("Datos del servicio") {
                Picker("Tipo", selection: Binding(
                    get: { vm.selectedBillType },
                    set: { vm.selectedBillType = $0 }
                )) {
                    ForEach(BillType.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                TextField("Referencia", text: Binding(
                    get: { vm.billReference },
                    set: { vm.billReference = $0 }
                )).autocorrectionDisabled()
            }
            Section("Monto") {
                TextField("Monto", text: Binding(
                    get: { vm.amountText },
                    set: { vm.amountText = $0 }
                )).keyboardType(.decimalPad)
                TextField("Moneda", text: Binding(
                    get: { vm.currency },
                    set: { vm.currency = $0 }
                ))
            }
            Section {
                Button {
                    Task { await vm.submit() }
                } label: {
                    if vm.isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Enviar Pago").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!vm.isFormValid || vm.isSubmitting)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onChange(of: vm.didSubmitSuccessfully) { _, new in
            if new { dismiss() }
        }
    }
}

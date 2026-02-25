import SwiftUI
import YunoChallengeSDK

/// A modal form for composing and submitting a new bill payment.
///
/// `PaymentSubmissionView` is presented as a sheet from `PaymentDashboardView`
/// when the user taps "Pay Bill". It delegates all state management to a
/// `PaymentSubmissionViewModel` created lazily in `.onAppear`.
///
/// The form collects:
/// - Bill type via a `Picker` populated from `BillType.allCases`.
/// - Bill reference via a plain `TextField`.
/// - Amount via a decimal keyboard `TextField`.
/// - Currency via a plain `TextField` (defaults to `"USD"`).
///
/// On successful submission the view dismisses itself automatically by observing
/// `PaymentSubmissionViewModel.didSubmitSuccessfully` via `onChange(of:)`.
struct PaymentSubmissionView: View {

    // MARK: - Properties

    /// The SDK singleton, received from the parent view's environment.
    @EnvironmentObject private var sdk: YunoChallengeSDK

    /// SwiftUI dismiss action used to close the sheet programmatically.
    @Environment(\.dismiss) private var dismiss

    /// The lazily initialized view model; `nil` until `.onAppear` fires.
    @State private var viewModel: PaymentSubmissionViewModel?

    // MARK: - Body

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

    // MARK: - Private Helpers

    /// Builds the form content when the view model is available.
    ///
    /// Bindings are constructed manually from the `@Observable` view model rather
    /// than using `@Bindable` to maintain compatibility with the lazy initialization
    /// pattern (`viewModel` is an optional `@State`).
    ///
    /// - Parameter vm: The initialized `PaymentSubmissionViewModel` to bind against.
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

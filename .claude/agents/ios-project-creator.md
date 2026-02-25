Create a complete iOS SwiftUI project called RemesaRapidaApp in the current directory (~/Projects/RemesaRapida/).

App description: A resilient iOS payment demo app with an embedded Swift Package SDK (YunoChallengeSDK) for offline-capable bill payments with idempotency, retry logic, and network monitoring.

Architecture: Clean Architecture + Observable MVVM (iOS 17+).

MANDATORY STEPS IN ORDER:

## STEP 1: Create YunoChallengeSDK Swift Package FIRST

Run these mkdir commands:
mkdir -p YunoChallengeSDK/Sources/YunoChallengeSDK/Models
mkdir -p YunoChallengeSDK/Sources/YunoChallengeSDK/Protocols
mkdir -p YunoChallengeSDK/Sources/YunoChallengeSDK/Data
mkdir -p YunoChallengeSDK/Sources/YunoChallengeSDK/Services
mkdir -p Sources/App
mkdir -p Sources/Features/Dashboard
mkdir -p Sources/Features/Submission
mkdir -p Sources/Features/NetworkSimulator
mkdir -p Resources/Assets.xcassets/AccentColor.colorset
mkdir -p Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p Tests

Create YunoChallengeSDK/Package.swift:
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "YunoChallengeSDK",
    platforms: [.iOS(.v17)],
    products: [.library(name: "YunoChallengeSDK", targets: ["YunoChallengeSDK"])],
    targets: [.target(name: "YunoChallengeSDK", path: "Sources/YunoChallengeSDK", swiftSettings: [.swiftLanguageMode(.v6)])]
)

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Models/BillType.swift:
import Foundation
public enum BillType: String, Codable, CaseIterable, Sendable {
    case electricity, water, phone, internet
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Models/PaymentStatus.swift:
import Foundation
public enum PaymentStatus: String, Codable, Sendable {
    case queued, processing, approved, declined, failed
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Models/PaymentRequest.swift:
import Foundation
public struct PaymentRequest: Codable, Sendable {
    public let billType: BillType
    public let billReference: String
    public let amount: Decimal
    public let currency: String
    public init(billType: BillType, billReference: String, amount: Decimal, currency: String) {
        self.billType = billType
        self.billReference = billReference
        self.amount = amount
        self.currency = currency
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Models/Payment.swift:
import Foundation
public struct Payment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let idempotencyKey: UUID
    public let request: PaymentRequest
    public var status: PaymentStatus
    public var retryCount: Int
    public let createdAt: Date
    public var updatedAt: Date
    public init(
        id: UUID = UUID(),
        idempotencyKey: UUID = UUID(),
        request: PaymentRequest,
        status: PaymentStatus = .queued,
        retryCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.request = request
        self.status = status
        self.retryCount = retryCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Protocols/PaymentQueueProtocol.swift:
import Foundation
public protocol PaymentQueueProtocol: Sendable {
    func enqueue(_ payment: Payment) async
    func dequeueAll() async -> [Payment]
    func update(_ payment: Payment) async
    func remove(id: UUID) async
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Protocols/PaymentAPIProtocol.swift:
import Foundation
public protocol PaymentAPIProtocol: Sendable {
    func submit(_ payment: Payment) async throws -> PaymentStatus
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Protocols/NetworkMonitorProtocol.swift:
import Foundation
public protocol NetworkMonitorProtocol: Sendable {
    var isConnected: Bool { get async }
    var connectionUpdates: AsyncStream<Bool> { get }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Data/LocalPaymentQueue.swift:
import Foundation
public actor LocalPaymentQueue: PaymentQueueProtocol {
    private let key = "com.yunochallengesdk.queue"
    private var payments: [Payment] = []
    public init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Payment].self, from: data) {
            payments = decoded
        }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(payments) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    public func enqueue(_ payment: Payment) async {
        payments.append(payment)
        persist()
    }
    public func dequeueAll() async -> [Payment] {
        return payments
    }
    public func update(_ payment: Payment) async {
        if let idx = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[idx] = payment
            persist()
        }
    }
    public func remove(id: UUID) async {
        payments.removeAll { $0.id == id }
        persist()
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Data/MockPaymentAPI.swift:
import Foundation
public struct MockPaymentAPI: PaymentAPIProtocol {
    public init() {}
    public func submit(_ payment: Payment) async throws -> PaymentStatus {
        let bucket = abs(payment.request.billReference.hashValue) % 11
        switch bucket {
        case 0...6:
            let delay = Double.random(in: 0.5...3.0)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .approved
        case 7...8:
            try await Task.sleep(nanoseconds: 200_000_000)
            return .declined
        case 9:
            try await Task.sleep(nanoseconds: 500_000_000)
            throw URLError(.timedOut)
        default:
            try await Task.sleep(nanoseconds: 300_000_000)
            throw URLError(.badServerResponse)
        }
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Services/SystemNetworkMonitor.swift:
import Foundation
import Network
public actor SystemNetworkMonitor: NetworkMonitorProtocol {
    private var _isConnected: Bool = true
    private let pathMonitor = NWPathMonitor()
    nonisolated(unsafe) private var continuation: AsyncStream<Bool>.Continuation?
    public let connectionUpdates: AsyncStream<Bool>
    public init() {
        var cont: AsyncStream<Bool>.Continuation?
        let stream = AsyncStream<Bool> { continuation in
            cont = continuation
        }
        self.connectionUpdates = stream
        self.continuation = cont
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { [weak self] in
                await self?.handlePathUpdate(connected)
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.yunochallengesdk.network"))
    }
    private func handlePathUpdate(_ connected: Bool) {
        _isConnected = connected
        continuation?.yield(connected)
    }
    public var isConnected: Bool {
        return _isConnected
    }
    public func setConnected(_ connected: Bool) {
        _isConnected = connected
        continuation?.yield(connected)
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Services/IdempotencyManager.swift:
import Foundation
public actor IdempotencyManager {
    private let key = "com.yunochallengesdk.idempotency"
    private var submittedKeys: Set<UUID> = []
    public init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            submittedKeys = Set(decoded)
        }
    }
    public func hasBeenSubmitted(key: UUID) -> Bool {
        submittedKeys.contains(key)
    }
    public func markSubmitted(key: UUID) {
        submittedKeys.insert(key)
        if let data = try? JSONEncoder().encode(Array(submittedKeys)) {
            UserDefaults.standard.set(data, forKey: self.key)
        }
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Services/RetryPolicy.swift:
import Foundation
public enum RetryDecision: Sendable {
    case retry(delay: TimeInterval)
    case permanentFailure
}
public struct RetryPolicy: Sendable {
    public static let maxAttempts = 3
    public static let baseDelay: TimeInterval = 1.0
    public static func decide(error: Error, attempt: Int) -> RetryDecision {
        if attempt >= maxAttempts { return .permanentFailure }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .notConnectedToInternet, .networkConnectionLost, .badServerResponse:
                return .retry(delay: baseDelay * pow(2.0, Double(attempt)))
            default:
                return .permanentFailure
            }
        }
        return .permanentFailure
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/Services/PaymentSyncService.swift:
import Foundation
@MainActor
public final class PaymentSyncService {
    private let queue: any PaymentQueueProtocol
    private let api: any PaymentAPIProtocol
    private let monitor: any NetworkMonitorProtocol
    private let idempotencyManager: IdempotencyManager
    public var onPaymentsUpdated: (@Sendable ([Payment]) -> Void)?
    public init(
        queue: any PaymentQueueProtocol,
        api: any PaymentAPIProtocol,
        monitor: any NetworkMonitorProtocol,
        idempotencyManager: IdempotencyManager
    ) {
        self.queue = queue
        self.api = api
        self.monitor = monitor
        self.idempotencyManager = idempotencyManager
    }
    public func start() {
        Task { [weak self] in
            guard let self else { return }
            for await connected in self.monitor.connectionUpdates {
                if connected {
                    await self.processQueue()
                }
            }
        }
    }
    public func submit(_ request: PaymentRequest) async throws {
        let payment = Payment(request: request)
        await queue.enqueue(payment)
        let connected = await monitor.isConnected
        if connected {
            await processQueue()
        }
        let all = await queue.dequeueAll()
        onPaymentsUpdated?(all)
    }
    public func processQueue() async {
        let all = await queue.dequeueAll()
        let pending = all.filter { $0.status == .queued || $0.status == .failed }
        var updated = all
        for payment in pending {
            var mutablePayment = payment
            await submitWithRetry(&mutablePayment)
            if let idx = updated.firstIndex(where: { $0.id == mutablePayment.id }) {
                updated[idx] = mutablePayment
            }
            await queue.update(mutablePayment)
        }
        onPaymentsUpdated?(updated)
    }
    private func submitWithRetry(_ payment: inout Payment) async {
        let alreadySubmitted = await idempotencyManager.hasBeenSubmitted(key: payment.idempotencyKey)
        if alreadySubmitted {
            payment.status = .approved
            payment.updatedAt = Date()
            return
        }
        payment.status = .processing
        payment.updatedAt = Date()
        await queue.update(payment)
        var attempt = 0
        while attempt < RetryPolicy.maxAttempts {
            do {
                let status = try await api.submit(payment)
                payment.status = status
                payment.updatedAt = Date()
                if status == .approved {
                    await idempotencyManager.markSubmitted(key: payment.idempotencyKey)
                }
                return
            } catch {
                let decision = RetryPolicy.decide(error: error, attempt: attempt)
                switch decision {
                case .retry(let delay):
                    attempt += 1
                    payment.retryCount += 1
                    payment.status = .processing
                    payment.updatedAt = Date()
                    await queue.update(payment)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                case .permanentFailure:
                    payment.status = .failed
                    payment.updatedAt = Date()
                    return
                }
            }
        }
        payment.status = .failed
        payment.updatedAt = Date()
    }
}

Create YunoChallengeSDK/Sources/YunoChallengeSDK/YunoChallengeSDK.swift:
import Foundation
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
        let service = PaymentSyncService(
            queue: queue,
            api: api,
            monitor: monitor,
            idempotencyManager: IdempotencyManager()
        )
        service.onPaymentsUpdated = { [weak self] updated in
            Task { @MainActor [weak self] in
                self?.payments = updated
            }
        }
        service.start()
        syncService = service
    }
    public func submitPayment(_ request: PaymentRequest) async throws {
        try await syncService?.submit(request)
    }
}

## STEP 2: Create project.yml

Create project.yml in ~/Projects/RemesaRapida/:
name: RemesaRapidaApp
options:
  bundleIdPrefix: com.remesarapida
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.2"
  generateEmptyDirectories: true
  createIntermediateGroups: true
packages:
  YunoChallengeSDK:
    path: YunoChallengeSDK
targets:
  RemesaRapidaApp:
    type: application
    platform: iOS
    sources:
      - path: Sources
        createIntermediateGroups: true
    resources:
      - path: Resources
    dependencies:
      - package: YunoChallengeSDK
    settings:
      base:
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
        INFOPLIST_FILE: Sources/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.remesarapida.RemesaRapidaApp
        DEVELOPMENT_TEAM: ""
        CODE_SIGN_STYLE: Automatic
  RemesaRapidaAppTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Tests
    dependencies:
      - target: RemesaRapidaApp
      - package: YunoChallengeSDK
    settings:
      base:
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
        PRODUCT_BUNDLE_IDENTIFIER: com.remesarapida.RemesaRapidaAppTests

## STEP 3: Create App Source Files

Create Sources/Info.plist:
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>RemesaRapida</string>
    <key>CFBundleDisplayName</key><string>RemesaRapida</string>
    <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
    <key>CFBundlePackageType</key><string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>UILaunchScreen</key><dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>

Create Resources/Assets.xcassets/Contents.json:
{"info":{"author":"xcode","version":1}}

Create Resources/Assets.xcassets/AccentColor.colorset/Contents.json:
{"colors":[{"idiom":"universal"}],"info":{"author":"xcode","version":1}}

Create Resources/Assets.xcassets/AppIcon.appiconset/Contents.json:
{"images":[{"idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}

Create Sources/App/AppContainer.swift:
import Foundation
import YunoChallengeSDK

@MainActor
final class AppContainer {
    let sdk: YunoChallengeSDK
    let networkMonitor: SystemNetworkMonitor

    init() {
        let monitor = SystemNetworkMonitor()
        networkMonitor = monitor
        sdk = YunoChallengeSDK.shared
        sdk.configure(
            queue: LocalPaymentQueue(),
            api: MockPaymentAPI(),
            monitor: monitor
        )
    }
}

Create Sources/App/RemesaRapidaApp.swift:
import SwiftUI
import YunoChallengeSDK

private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: SystemNetworkMonitor? = nil
}

extension EnvironmentValues {
    var networkMonitor: SystemNetworkMonitor? {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}

@main
struct RemesaRapidaApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            PaymentDashboardView()
                .environmentObject(container.sdk)
                .environment(\.networkMonitor, container.networkMonitor)
        }
    }
}

Create Sources/Features/Dashboard/PaymentDashboardViewModel.swift:
import Foundation
import Observation
import YunoChallengeSDK

@Observable
@MainActor
final class PaymentDashboardViewModel {
    private let sdk: YunoChallengeSDK

    var payments: [Payment] { sdk.payments }

    var pendingCount: Int {
        payments.filter { $0.status == .queued || $0.status == .processing }.count
    }

    var approvedTotal: Decimal {
        payments
            .filter { $0.status == .approved }
            .reduce(.zero) { $0 + $1.request.amount }
    }

    init(sdk: YunoChallengeSDK) {
        self.sdk = sdk
    }
}

Create Sources/Features/Dashboard/PaymentDashboardView.swift:
import SwiftUI
import YunoChallengeSDK

struct StatusBadge: View {
    let status: PaymentStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
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

struct PaymentRowView: View {
    let payment: Payment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(payment.request.billType.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                StatusBadge(status: payment.status)
            }
            Text(payment.request.billReference)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("\(payment.request.currency) \(payment.request.amount, format: .number)")
                    .font(.subheadline.bold())
                if payment.retryCount > 0 {
                    Text("Retry #\(payment.retryCount)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PaymentDashboardView: View {
    @EnvironmentObject private var sdk: YunoChallengeSDK
    @Environment(\.networkMonitor) private var networkMonitor
    @State private var showPaymentForm = false
    @State private var showNetworkSimulator = false
    @State private var viewModel: PaymentDashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("RemesaRapida")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPaymentForm = true
                    } label: {
                        Label("Pay Bill", systemImage: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showNetworkSimulator = true
                    } label: {
                        Label("Network", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .sheet(isPresented: $showPaymentForm) {
                PaymentSubmissionView()
                    .environmentObject(sdk)
            }
            .sheet(isPresented: $showNetworkSimulator) {
                if let monitor = networkMonitor {
                    NetworkSimulatorView(monitor: monitor)
                }
            }
            .onAppear {
                viewModel = PaymentDashboardViewModel(sdk: sdk)
            }
        }
    }

    @ViewBuilder
    private func content(vm: PaymentDashboardViewModel) -> some View {
        if vm.payments.isEmpty {
            ContentUnavailableView(
                "No Payments Yet",
                systemImage: "banknote",
                description: Text("Tap + to submit your first bill payment.")
            )
        } else {
            List {
                Section("Summary") {
                    LabeledContent("Pending", value: "\(vm.pendingCount)")
                    LabeledContent("Approved Total", value: "USD \(vm.approvedTotal)")
                }
                Section("Payments") {
                    ForEach(vm.payments) { payment in
                        PaymentRowView(payment: payment)
                    }
                }
            }
        }
    }
}

#Preview {
    PaymentDashboardView()
        .environmentObject(YunoChallengeSDK.shared)
}

Create Sources/Features/Submission/PaymentSubmissionViewModel.swift:
import Foundation
import Observation
import YunoChallengeSDK

@Observable
@MainActor
final class PaymentSubmissionViewModel {
    var selectedBillType: BillType = .electricity
    var billReference: String = ""
    var amountText: String = ""
    var currency: String = "USD"
    var isSubmitting: Bool = false
    var errorMessage: String?
    var didSubmitSuccessfully: Bool = false

    var isFormValid: Bool {
        !billReference.isEmpty && Decimal(string: amountText) != nil
    }

    private let sdk: YunoChallengeSDK

    init(sdk: YunoChallengeSDK) {
        self.sdk = sdk
    }

    func submit() async {
        guard isFormValid, let amount = Decimal(string: amountText) else {
            errorMessage = "Please fill all fields with valid values."
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let request = PaymentRequest(
                billType: selectedBillType,
                billReference: billReference,
                amount: amount,
                currency: currency
            )
            try await sdk.submitPayment(request)
            didSubmitSuccessfully = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

Create Sources/Features/Submission/PaymentSubmissionView.swift:
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
                    form(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Pay a Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel = PaymentSubmissionViewModel(sdk: sdk)
            }
        }
    }

    @ViewBuilder
    private func form(vm: PaymentSubmissionViewModel) -> some View {
        Form {
            Section("Bill Details") {
                Picker("Bill Type", selection: Binding(
                    get: { vm.selectedBillType },
                    set: { vm.selectedBillType = $0 }
                )) {
                    ForEach(BillType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                TextField("Bill Reference", text: Binding(
                    get: { vm.billReference },
                    set: { vm.billReference = $0 }
                ))
                .autocorrectionDisabled()
            }
            Section("Amount") {
                TextField("Amount", text: Binding(
                    get: { vm.amountText },
                    set: { vm.amountText = $0 }
                ))
                .keyboardType(.decimalPad)
                Picker("Currency", selection: Binding(
                    get: { vm.currency },
                    set: { vm.currency = $0 }
                )) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("MXN").tag("MXN")
                }
            }
            Section {
                Button {
                    Task { await vm.submit() }
                } label: {
                    if vm.isSubmitting {
                        HStack {
                            ProgressView()
                            Text("Submitting...")
                        }
                    } else {
                        Text("Submit Payment")
                            .frame(maxWidth: .infinity)
                            .bold()
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

Create Sources/Features/NetworkSimulator/NetworkSimulatorViewModel.swift:
import Foundation
import Observation
import YunoChallengeSDK

@Observable
@MainActor
final class NetworkSimulatorViewModel {
    var isSimulatingOffline: Bool = false
    var statusMessage: String = "Connected"
    private var monitor: SystemNetworkMonitor?

    func configure(monitor: SystemNetworkMonitor) {
        self.monitor = monitor
    }

    func toggleOffline() async {
        guard let monitor else { return }
        isSimulatingOffline.toggle()
        await monitor.setConnected(!isSimulatingOffline)
        statusMessage = isSimulatingOffline ? "Offline (Simulated)" : "Connected"
    }
}

Create Sources/Features/NetworkSimulator/NetworkSimulatorView.swift:
import SwiftUI
import YunoChallengeSDK

struct NetworkSimulatorView: View {
    let monitor: SystemNetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NetworkSimulatorViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    Toggle("Simulate Offline", isOn: Binding(
                        get: { viewModel.isSimulatingOffline },
                        set: { _ in Task { await viewModel.toggleOffline() } }
                    ))
                    LabeledContent("Status", value: viewModel.statusMessage)
                        .foregroundStyle(viewModel.isSimulatingOffline ? .red : .green)
                }
                Section("About") {
                    Text("Use this tool to simulate offline conditions. Payments submitted while offline will be queued and automatically retried when connectivity is restored.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Network Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                viewModel.configure(monitor: monitor)
            }
        }
    }
}

## STEP 4: Install xcodegen, generate, and build

Run:
which xcodegen || brew install xcodegen
cd ~/Projects/RemesaRapida && xcodegen generate

Then find an available iPhone simulator and build:
SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; iphones=[v for k,vs in d.items() if 'iOS' in k for v in vs if 'iPhone' in v['name'] and v['isAvailable']]; print(iphones[0]['udid'] if iphones else '')" 2>/dev/null)
echo "Using simulator: $SIMULATOR_ID"
which xcpretty || gem install xcpretty
xcodebuild build -scheme RemesaRapidaApp -destination "id=$SIMULATOR_ID" CODE_SIGNING_ALLOWED=NO 2>&1 | xcpretty
BUILD_RESULT=${PIPESTATUS[0]}

## STEP 5: Fix ALL errors until build is green

If BUILD_RESULT != 0, read every xcpretty error line, fix the Swift files, and re-run xcodebuild until exit code is 0.

Common Swift 6 fixes:
- Actor stored properties: use nonisolated(unsafe) var for continuation
- @Sendable on closures crossing actor boundaries
- nonisolated keyword for protocol conformance non-isolated getters
- If YunoChallengeSDK has @MainActor PaymentSyncService calling actor methods, use await properly

## STEP 6: Open Xcode after green build
open RemesaRapidaApp.xcodeproj

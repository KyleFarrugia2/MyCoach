import SwiftUI
import Vision
import VisionKit

/// Live camera barcode scanner (VisionKit `DataScannerViewController`) with manual entry fallback.
/// Only codes with a valid GS1 check digit are accepted, which filters out misreads.
struct BarcodeScannerView: View {
    let onDetected: (String) -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var manual = ""
    @State private var manualError: String?

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    if scannerAvailable {
                        DataScannerRepresentable(onCode: onDetected)
                            .frame(maxWidth: .infinity)
                            .frame(height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous))
                        Text("Line the barcode up in the frame. It scans automatically.")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            .frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView(
                            "Camera scanning unavailable",
                            systemImage: "barcode.viewfinder",
                            description: Text(
                                DataScannerViewController.isSupported
                                    ? "Allow camera access in Settings → My Coach, or type the barcode number below."
                                    : "This device can't scan barcodes. Type the barcode number below."
                            )
                        )
                    }

                    VStack(alignment: .leading, spacing: MCTheme.Spacing.xs) {
                        Text("Or type the barcode number")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        TextField("e.g. 3017620422003", text: $manual)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: manual) { _, _ in manualError = nil }
                        if let manualError {
                            Text(manualError)
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.ColorToken.danger)
                        }
                        MCSecondaryButton(title: "Look Up", isEnabled: manual.filter(\.isNumber).count >= 8) {
                            if let code = BarcodeLookup.normalize(manual) {
                                onDetected(code)
                            } else {
                                manualError = "That doesn't look like a valid 8, 12, 13 or 14-digit barcode."
                            }
                        }
                    }
                }
                .padding(MCTheme.Spacing.screenHorizontal)
            }
            .mcScreenBackground()
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // EAN-13 also covers UPC-A (reported with a leading 0).
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if !controller.isScanning, !context.coordinator.fired {
            try? controller.startScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        var fired = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !fired else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue,
                      let code = BarcodeLookup.normalize(payload) else { continue }
                fired = true
                dataScanner.stopScanning()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onCode(code)
                return
            }
        }
    }
}

/// Scan → look up (My Foods first, then Open Food Facts) → user checks the label values → save.
/// Unknown products open a blank editor tied to the barcode, so the next scan finds them instantly offline.
struct ScanFoodFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let onFood: (FoodItem) -> Void

    private enum Stage {
        case scan
        case lookup(String)
        case review(FoodItem, String)
    }

    @State private var stage: Stage = .scan

    var body: some View {
        switch stage {
        case .scan:
            BarcodeScannerView(onDetected: handle, onClose: { dismiss() })
        case .lookup(let code):
            NavigationStack {
                VStack(spacing: MCTheme.Spacing.md) {
                    ProgressView()
                    Text("Finding \(code)…")
                        .font(MCTheme.Typography.headline)
                    Text("Searching the Open Food Facts product database.")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Looking Up")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        case .review(let food, let notice):
            CustomFoodEditorView(prefill: food, notice: notice, title: "Check Nutrition") { saved in
                env.saveCustomFood(saved)
                onFood(saved)
            }
        }
    }

    private func handle(_ code: String) {
        if let local = env.customFood(barcode: code) {
            onFood(local)
            return
        }
        stage = .lookup(code)
        Task {
            let result = await OpenFoodFactsClient().lookup(barcode: code)
            switch result {
            case .found(let product):
                stage = .review(
                    product.food,
                    product.complete
                        ? BarcodeLookup.attribution
                        : "Some nutrition values are missing from the database. Fill them in from the label (per 100 g)."
                )
            case .notFound:
                stage = .review(
                    BarcodeLookup.blankFood(barcode: code),
                    "This product isn't in the database yet. Enter the nutrition from the label (per 100 g). Next time it scans instantly."
                )
            case .failed(let message):
                stage = .review(BarcodeLookup.blankFood(barcode: code), message)
            }
        }
    }
}

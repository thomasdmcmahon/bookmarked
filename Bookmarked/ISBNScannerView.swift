
import SwiftUI
import VisionKit
import Vision

// MARK: - Scanner Screen

struct ISBNScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let onScan: (String) -> Void

    @State private var scannerError: String?

    private var scannerSupported: Bool {
        DataScannerViewController.isSupported
    }

    var body: some View {
        NavigationStack {
            Group {
                if !scannerSupported {
                    ContentUnavailableView(
                        "Scanner Not Supported",
                        systemImage: "camera.fill",
                        description: Text(
                            "ISBN scanning requires a compatible iPhone running iOS 16 or later."
                        )
                    )

                } else if !DataScannerViewController.isAvailable {
                    ContentUnavailableView(
                        "Camera Unavailable",
                        systemImage: "camera.fill",
                        description: Text(
                            "Check camera permissions in Settings and try again."
                        )
                    )

                } else {
                    ZStack(alignment: .bottom) {
                        BarcodeScannerRepresentable(
                            onScan: { isbn in
                                onScan(isbn)
                                dismiss()
                            },
                            onError: { message in
                                scannerError = message
                            }
                        )
                        .ignoresSafeArea(edges: .bottom)

                        VStack(spacing: 8) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)

                            Text("Scan a Book ISBN")
                                .font(.headline)

                            Text(
                                "Point your camera at the barcode on the back of the book."
                            )
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.8))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )
                        .padding()
                    }
                }
            }
            .navigationTitle("Scan ISBN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(
                "Scanner Error",
                isPresented: Binding(
                    get: { scannerError != nil },
                    set: { if !$0 { scannerError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerError ?? "")
            }
        }
    }
}

// MARK: - VisionKit Integration

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {

    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(
        context: Context
    ) -> DataScannerViewController {

        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator

        return scanner
    }

    func updateUIViewController(
        _ controller: DataScannerViewController,
        context: Context
    ) {
        guard !controller.isScanning,
              !context.coordinator.hasScanned else {
            return
        }

        Task { @MainActor in
            do {
                try controller.startScanning()
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    static func dismantleUIViewController(
        _ controller: DataScannerViewController,
        coordinator: Coordinator
    ) {
        if controller.isScanning {
            controller.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onScan: onScan,
            onError: onError
        )
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        let onScan: (String) -> Void
        let onError: (String) -> Void

        var hasScanned = false

        init(
            onScan: @escaping (String) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onScan = onScan
            self.onError = onError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasScanned else { return }

            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else {
                    continue
                }

                let isbn = OpenLibraryService.normalizeISBN(
                    payload
                )

                // Only accept ISBN-13, not arbitrary EAN-13 codes.
                guard isbn.hasPrefix("978") ||
                      isbn.hasPrefix("979") else {
                    continue
                }

                guard isbn.count == 13,
                      OpenLibraryService.isValidISBN(isbn) else {
                    continue
                }

                hasScanned = true

                dataScanner.stopScanning()
                onScan(isbn)

                return
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onError(error.localizedDescription)
        }
    }
}


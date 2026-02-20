import CoreNFC
import Observation

@MainActor
@Observable
class NFCAttendanceService: NSObject, NFCNDEFReaderSessionDelegate {
    var scannedStudentId: String?
    var isScanning = false
    var lastError: String?
    var scanResult: ScanResult?

    enum ScanResult: Equatable {
        case success(studentName: String)
        case error(String)
    }

    private var session: NFCNDEFReaderSession?

    var isNFCAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func startScanning() {
        guard isNFCAvailable else {
            lastError = "NFC is not available on this device"
            scanResult = .error("NFC is not available on this device")
            return
        }
        lastError = nil
        scanResult = nil
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your school ID near the device to check in"
        session?.begin()
        isScanning = true
    }

    func reset() {
        scannedStudentId = nil
        scanResult = nil
        lastError = nil
        isScanning = false
    }

    // MARK: - NFCNDEFReaderSessionDelegate (nonisolated)

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            if let nfcError = error as? NFCReaderError,
               nfcError.code != .readerSessionInvalidationErrorFirstNDEFTagRead {
                self.lastError = error.localizedDescription
                self.scanResult = .error(error.localizedDescription)
            }
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        Task { @MainActor in
            self.isScanning = false
            for message in messages {
                for record in message.records {
                    if let payload = String(data: record.payload, encoding: .utf8) {
                        self.scannedStudentId = payload
                        self.scanResult = .success(studentName: payload)
                    }
                }
            }
        }
    }
}

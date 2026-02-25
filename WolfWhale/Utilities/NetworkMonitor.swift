import Foundation
import Network

nonisolated enum ConnectionType: String, Sendable {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case wiredEthernet = "Wired Ethernet"
    case none = "No Connection"
}

@Observable
@MainActor
final class NetworkMonitor {

    // MARK: - Published State

    var isConnected = true
    var connectionType: ConnectionType = .wifi
    /// True when the path uses an expensive interface (e.g. cellular).
    var isExpensive = false
    /// True when the system is in Low Data Mode.
    var isConstrained = false

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.wolfwhale.lms.networkmonitor")

    // MARK: - Lifecycle

    init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // NWPathMonitor's pathUpdateHandler fires on the provided queue,
        // which is a background DispatchQueue. We hop to MainActor inside.
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            let type = self.resolveConnectionType(path)
            let expensive = path.isExpensive
            let constrained = path.isConstrained

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = connected
                self.connectionType = type
                self.isExpensive = expensive
                self.isConstrained = constrained
            }
        }
        monitor.start(queue: queue)
    }

    // nonisolated because it is called from the NWPathMonitor callback queue
    nonisolated private func resolveConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .none
        }
    }
}

import Foundation
import Network

/// Single responsibility: watch device reachability and report
/// offline/online transitions. Nothing else.
final class NetworkMonitorService: NetworkMonitoring {

    private var monitor: NWPathMonitor?
    private let queue: DispatchQueue

    init(queue: DispatchQueue = .global()) {
        self.queue = queue
    }

    func startMonitoring(onStatusChange: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        self.monitor = monitor

        monitor.pathUpdateHandler = { path in
            let isOffline = path.status != .satisfied
            DispatchQueue.main.async {
                onStatusChange(isOffline)
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }

    deinit {
        stopMonitoring()
    }
}
//
//  NetworkMonitor.swift
//  sd-smart-parking
//
//  Created by Mateo on 16/04/26.
//
import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    @Published var isConnected: Bool = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let status = path.status == .satisfied
                if self?.isConnected != status {
                    self?.isConnected = status
                }
            }
        }
        monitor.start(queue: queue)
    }
}

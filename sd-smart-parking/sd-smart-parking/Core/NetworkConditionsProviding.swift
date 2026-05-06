//
//  NetworkConditionsProviding.swift
//  sd-smart-parking
//
//  Permite inyectar el estado de red en VMs/vistas y mockearlo en tests
//  sin acoplar al NetworkMonitor concreto. NetworkMonitor conforma vía
//  extension; mocks proveen su propia implementación.
//

import Foundation

@MainActor
protocol NetworkConditionsProviding: AnyObject {
    var isConnected: Bool { get }
}

extension NetworkMonitor: NetworkConditionsProviding {}

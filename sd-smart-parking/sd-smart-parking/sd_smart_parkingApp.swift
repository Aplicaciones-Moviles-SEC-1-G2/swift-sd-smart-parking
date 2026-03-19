//
//  sd_smart_parkingApp.swift
//  sd-smart-parking
//
//  Created by Mateo on 19/03/26.
//

import SwiftUI

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct sd_smart_parkingApp: App {
    
    @StateObject private var navigationManager = NavigationManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationManager)
        }
    }
}



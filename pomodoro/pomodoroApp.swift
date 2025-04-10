//
//  pomodoroApp.swift
//  pomodoro
//
//  Created by Jose Caldas on 10/04/25.
//

import SwiftUI

@main
struct pomodoroApp: App {
    @StateObject private var themeService = ThemeService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeService.currentTheme.colorScheme)
                .environmentObject(themeService)
        }
    }
}

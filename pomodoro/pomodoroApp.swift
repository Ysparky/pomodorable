//
//  pomodoroApp.swift
//  pomodoro
//
//  Created by Jose Caldas on 10/04/25.
//

import SwiftUI
import BackgroundTasks

@main
struct pomodoroApp: App {
    @StateObject private var themeService = ThemeService.shared
    @StateObject private var timerViewModel = TimerViewModel()
    
    init() {
        setupDefaultSettings()
        registerBackgroundTasks()
        configureLocalization()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeService.currentTheme.colorScheme)
                .environmentObject(themeService)
                .environmentObject(timerViewModel)
        }
    }
    
    private func configureLocalization() {
        // Ensure the main bundle can find the localization files
        Bundle.main.path(forResource: "en", ofType: "lproj")
        Bundle.main.path(forResource: "es", ofType: "lproj")
        Bundle.main.path(forResource: "pt", ofType: "lproj")
    }
    
    private func registerBackgroundTasks() {
        // Register background refresh task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.app.pomodoro.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Ensure the task completes if the app is terminated
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Schedule the next background refresh task
        scheduleAppRefresh()
        
        // Complete the current task
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.app.pomodoro.refresh")
        // Request an update in 15 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    private func setupDefaultSettings() {
        // Check if the app has already been configured
        let hasBeenConfigured = UserDefaults.standard.bool(forKey: "hasBeenConfigured")
        
        if !hasBeenConfigured {
            // First time running the app, set default values
            SettingsService.shared.resetToDefaults()
            
            // Mark as configured
            UserDefaults.standard.set(true, forKey: "hasBeenConfigured")
        }
    }
}

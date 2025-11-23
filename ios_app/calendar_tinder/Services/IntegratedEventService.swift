//
//  IntegratedEventService.swift
//  calendar_tinder
//
//  Integrated service that combines backend validation with EventKit
//

import Foundation
import Combine

class IntegratedEventService: ObservableObject {
    private let calendarService = CalendarService()
    private let reminderService = ReminderService()
    private let apiService = BackendAPIService.shared

    @Published var lastError: Error?
    @Published var lastSuccessMessage: String?

    // MARK: - Calendar Events

    /// Adds event directly to Apple Calendar (no backend validation needed)
    func addCalendarEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false
    ) async -> Bool {
        do {
            // Add directly to Apple Calendar via EventKit
            _ = try await calendarService.addEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes,
                isAllDay: isAllDay
            )

            await MainActor.run {
                self.lastSuccessMessage = "✓ Event added to calendar!"
            }

            return true

        } catch {
            await MainActor.run {
                self.lastError = error
            }
            return false
        }
    }

    // MARK: - Reminders

    /// Adds reminder directly to Apple Reminders (no backend validation needed)
    func addReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int = 0
    ) async -> Bool {
        do {
            // Add directly to Apple Reminders via EventKit
            _ = try await reminderService.addReminder(
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority
            )

            await MainActor.run {
                self.lastSuccessMessage = "✓ Reminder added!"
            }

            return true

        } catch {
            await MainActor.run {
                self.lastError = error
            }
            return false
        }
    }

    // MARK: - Permission Requests

    func requestCalendarPermission() async throws -> Bool {
        return try await calendarService.requestCalendarAccess()
    }

    func requestReminderPermission() async throws -> Bool {
        return try await reminderService.requestReminderAccess()
    }
}

// MARK: - Errors

enum IntegratedEventError: LocalizedError {
    case validationFailed(String)
    case addEventFailed
    case addReminderFailed

    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .addEventFailed:
            return "Failed to add event to calendar"
        case .addReminderFailed:
            return "Failed to add reminder"
        }
    }
}

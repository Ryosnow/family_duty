import Foundation

protocol CalendarProviding {
    var calendar: Calendar { get }
}

struct SystemCalendarProvider: CalendarProviding {
    var calendar: Calendar { .current }
}

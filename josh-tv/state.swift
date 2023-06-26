//
//  state.swift
//  josh-tv
//
//  Created by Jeffrey Sisson on 6/24/23.
//

import Foundation
import SQLite3
import SwiftUI

struct Event: Identifiable, Equatable, Hashable {
    let id = UUID()
    let title: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let startDayIndex: Int // Index of the day within the calendar
    let endDayIndex: Int // Index of the day within the calendar
}

struct MediaItem {
    let duration: TimeInterval
    let title: String
}

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) { srand48(seed) }
    func next() -> UInt64 { return UInt64(drand48() * Double(UInt64.max)) }
}

// used to seed the random number generator predictably for a given week's window
func previousSundayDate() -> Int {
    let calendar = Calendar.current
    let today = Date()
    
    // Find the current weekday (1 is Sunday, 2 is Monday, etc.)
    let currentWeekday = calendar.component(.weekday, from: today)
    
    // Calculate the number of days to subtract to reach the previous Sunday
    let daysToSubtract = (currentWeekday + 6) % 7
    
    // Subtract the days from the current date
    let previousSunday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
    
    // Extract the date as an integer
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    let previousSundayDate = Int(dateFormatter.string(from: previousSunday))!
    
    return previousSundayDate
}


class MediaItemsViewModel: ObservableObject {
    @Published var plexDB: URL?
    
    //    /Volumes/Plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db
    @Published var events: [Event] = []
    var db: OpaquePointer? = nil

    init(plexDB: URL? = nil, events: [Event] = [], db: OpaquePointer? = nil) {
        self.plexDB = plexDB
        self.events = events
        self.db = db

        if let data = UserDefaults.standard.data(forKey: "plex")  {
            var isStale = false
            do {
                let newUrl = try URL(resolvingBookmarkData: data,
                                     options: .withSecurityScope,
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale)
                guard newUrl.startAccessingSecurityScopedResource() else {
                    print("Could not start accessing security scoped resource: \(newUrl.path)")
                    return
                 }
                self.plexDB = newUrl
                self.openDatabase(withURL: newUrl)
            } catch {
                print("error \(error)")
            }
        }
    }
    
    
    func presentDialog() {
        let dialog = NSOpenPanel();
        dialog.title                    = "Choose a directory"
        dialog.showsResizeIndicator     = true
        dialog.showsHiddenFiles         = true
        dialog.allowsMultipleSelection  = false
        dialog.canChooseDirectories     = false
        dialog.canChooseFiles           = true
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            if let url = dialog.url {
                openDatabase(withURL: url)
            }
        } else {
            print("user cancelled")
            return
        }
    }
    
    func openDatabase(withURL url: URL) {
        let path = "file:" + url.path + "?immutable=1"
        print("opening sqlite for \(path)")
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            if let errorMessage = String(validatingUTF8: sqlite3_errmsg(db)) {
                print("Error opening database: \(errorMessage)")
            }
            return
        }

        
        var mediaItems: [MediaItem] = []
        
        let query = "select title, duration from metadata_items where duration is not null and metadata_type != 12;"
        var statement: OpaquePointer? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let title = String(cString: sqlite3_column_text(statement, 0))
                let milliseconds = sqlite3_column_int(statement, 1)
                let duration = TimeInterval(Int(milliseconds) / 1000)
                let mediaItem = MediaItem(duration: duration, title: title)
                mediaItems.append(mediaItem)
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Error preparing statement: \(errorMessage)")
        }
        
        sqlite3_finalize(statement)
        sqlite3_close(db)
        
        events = MediaItemsViewModel.createEvents(from: mediaItems)

        do {
            let data = try url.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: "plex")
        } catch {
            print("error setting prefs: \(error).")
        }
        
        plexDB = url
    }
    
    static func createEvents(from mediaItems: [MediaItem]) -> [Event] {
        var seededGenerator = RandomNumberGeneratorWithSeed(seed: previousSundayDate())

        let shuffled = mediaItems.shuffled(using: &seededGenerator)
        
        var events: [Event] = []
        var currentHour: Int = 0
        var currentMinute: Int = 0
        var currentDayIndex: Int = 0
        
        for mediaItem in shuffled {
            let duration = mediaItem.duration
            let startDayIndex = currentDayIndex
            let plusMinutes: Int64 = Int64(duration / 60)
            let plusHours: Int = Int(floor(Double(plusMinutes) / 60))
            var endHour: Int = currentHour + plusHours
            var endMinute: Int = (currentMinute + Int(plusMinutes % 60))
            if endMinute >= 60 {
                endHour += 1
                endMinute = endMinute - 60
            }

            if endHour >= 24 {
                currentDayIndex += endHour / 24
                endHour %= 24
            }
            
            let event = Event(title: mediaItem.title,
              startHour: currentHour,
              startMinute: currentMinute,
              endHour: endHour,
              endMinute: endMinute,
              startDayIndex: startDayIndex,
              endDayIndex: currentDayIndex
            )
            
            events.append(event)
            
            // Update the current time and day for the next event
            currentHour = endHour
            currentMinute = endMinute
            
        }
        
        return events
    }

    
}

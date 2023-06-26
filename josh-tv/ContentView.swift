//
//  ContentView.swift
//  josh-tv
//
//  Created by Jeffrey Sisson on 6/24/23.
//

import SwiftUI

let hourWidth: CGFloat = 50
let hourRowHeight: CGFloat = 30.0
let hourRowWidth: CGFloat = 200.0
let calendar = Calendar.current
let dayMinutes = CGFloat(24 * 60)

struct CalendarView: View {
    let startDate: Date
    let hourRange: ClosedRange<Int> = 0...23
    let events: [Event]
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
//        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<7) { dayIndex in
                    VStack(spacing: 0) {
                        Text(dayTitle(for: dayIndex))
                            .padding(.vertical, 8)
                            .font(.system(.body, design: .monospaced))

                        ZStack(alignment: .top){

                            VStack(spacing: 0) {
                                ForEach(hourRange, id: \.self) { hour in
                                    HourRow(hour: hour, dayIndex: dayIndex, events: events)
                                }
                            }
                            let dayElements = eventsForDay(dayIndex)
                            VStack(spacing:0) {
                                ForEach(dayElements, id: \.id) { event in
                                    EventView(event: event, dayIndex: dayIndex,
                                              isLast: event.title == dayElements.last?.title)
                                }
                            }
                            if dayIndex == 0 {
                                let components = calendar.dateComponents([.hour, .minute], from: startDate)
                                let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)


                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(.red)
                                    .offset(x: -1.5 * hourWidth, y: CGFloat(CGFloat(minutes) / dayMinutes) * (hourRowHeight * 24))
                                    .frame(width: hourWidth)
                            }
                            
                        }
                                                
                    }
                }
            }
        }
    }
    
    private func dayTitle(for dayIndex: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dayIndex, to: startDate)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        
        return dateFormatter.string(from: date).uppercased()
    }
    
    private func eventsForDay(_ dayIndex: Int) -> [Event] {
        let filteredEvents = events.filter { event in
            return event.startDayIndex == dayIndex || event.endDayIndex == dayIndex
        }
        
        return filteredEvents
    }
}

struct HourRow: View {
    let hour: Int
    let dayIndex: Int
    let events: [Event]
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(hour):00")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: hourWidth)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray)
        }
        .padding(0)
        .frame(width: hourRowWidth, height: hourRowHeight, alignment: .top)

    }
}

struct EventView: View {
    let event: Event
    let dayIndex: Int
    let isLast: Bool
    @State var isPopover = false
    
    var body: some View {
        ZStack(alignment:.center) {
            Rectangle()
                .fill(.purple)
                .border(Color.white, width: 1)
            Text(event.title)
                .foregroundColor(.white)
                .font(Font.custom("Trattatello", size: 16.0))
        }
        .onHover{over in
            if (over) {
                isPopover = true
            } else {
                isPopover = false
            }
        }
        .popover(isPresented: $isPopover) {
            Text(event.title)
                .font(Font.custom("Trattatello", size: 20.0))
                .padding()
        }
        .frame(width: hourRowWidth - hourWidth, height:  getEndHeight(), alignment: isLast ? .bottom : .top)
        .offset(x: hourWidth / 2)
    }
    
    
    private func getStartY() -> CGFloat {
        var startMinute = CGFloat(event.startMinute)
        var startHour = CGFloat(event.startHour)

        if event.startDayIndex != event.endDayIndex && dayIndex == event.endDayIndex {
            startMinute = 0
            startHour = 0
        }

        let positionY = startHour * hourRowHeight + ((startMinute / 60.0) * hourRowHeight)
        
        return positionY
    }
    
    private func getEndHeight() -> CGFloat {
        var endMinute = CGFloat(event.endMinute)
        var endHour = CGFloat(event.endHour)
        if event.startDayIndex != event.endDayIndex && dayIndex == event.startDayIndex {
            endMinute = 59
            endHour = 23
        }

        let positionY = endHour * hourRowHeight + ((endMinute / 60.0) * hourRowHeight)

        return positionY - getStartY()
    }

    
    
}

struct ContentView: View {
    let startDate = Date();
    var events: [Event];
    let onFile: () -> Void;
    let plexDB: URL?;

    func nowPlaying() -> Event? {
        let components = calendar.dateComponents([.hour, .minute], from: startDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return events.first(where: { event in
            if (event.startDayIndex != 0) {
                return false;
            }
            if (event.startHour == hour) {
                return event.startMinute <= minute && (event.endHour != hour || event.endMinute >= minute)
            }
            if (event.endHour == hour) {
                return event.endMinute >= minute;
            }
            if (event.endHour > hour) {
                return true;
            }
            return false
        })
    }
    
    var body: some View {
        VStack {
            HStack {
                if let np = nowPlaying() {
                    Text("Now playing:")
                        .font(Font.custom("Menlo", size: 16.0))
                    Text(np.title)
                        .font(Font.custom("Trattatello", size: 18.0))
                    Text("on")
                        .font(Font.custom("Menlo", size: 16.0))
                }
                Text("JOSH TV")
                    .font(Font.custom("Menlo", size: 16.0).bold())
                Button("Select plex database...", action: onFile)
                if let p = plexDB {
                    Text(p.path)
                        .font(Font.custom("Menlo", size: 12.0))
                        .frame(maxWidth: 300.0, maxHeight: 10.0)
                }
            }
            .padding(4)
            CalendarView(startDate: startDate, events: events)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    // Sample events
    static var events: [Event] = [
        Event(title: "Burning", startHour: 0, startMinute: 0, endHour: 2, endMinute: 28, startDayIndex: 0, endDayIndex:0),
        Event(title: "Last Exit to Brooklyn", startHour: 2, startMinute: 28, endHour: 4, endMinute: 10, startDayIndex: 0, endDayIndex:0),
        Event(title: "Microbe and Gasoline", startHour: 4, startMinute: 10, endHour: 5, endMinute: 53, startDayIndex: 0, endDayIndex:0),
        Event(title: "Milford Graves Full Mantis", startHour: 5, startMinute: 53, endHour: 7, endMinute: 24, startDayIndex: 0, endDayIndex:0),
        Event(title: "Mystery Train", startHour: 7, startMinute: 24, endHour: 9, endMinute: 10, startDayIndex: 0, endDayIndex:0),
        Event(title: "Pin", startHour: 9, startMinute: 10, endHour: 10, endMinute: 53, startDayIndex: 0, endDayIndex:0),
        Event(title: "The Passionate Thief", startHour: 10, startMinute: 53, endHour: 12, endMinute: 39, startDayIndex: 0, endDayIndex:0),
        Event(title: "Lover's Rock", startHour: 12, startMinute: 39, endHour: 14, endMinute: 14, startDayIndex: 0, endDayIndex:0),
        Event(title: "To Live and Die in L.A.", startHour: 14, startMinute: 14, endHour: 2, endMinute: 45, startDayIndex: 0, endDayIndex:1)
    ]

    static var previews: some View {
        ContentView(events: events, onFile: {}, plexDB: URL(string: "file:///Volumes/Plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"))
    }
}

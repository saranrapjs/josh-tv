//
//  josh_tvApp.swift
//  josh-tv
//
//  Created by Jeffrey Sisson on 6/24/23.
//

import SwiftUI

@main
struct josh_tvApp: App {
    @StateObject private var viewModel = MediaItemsViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView(events: viewModel.events, onFile: {
                viewModel.presentDialog()
            }, plexDB: viewModel.plexDB)
        }
    }
}

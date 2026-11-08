// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import SwiftUI

/// The root: a plain `TabView` with a `NavigationStack` per section.
///
/// Navigation is left entirely to the system. On iPhones it is the usual tab
/// bar. On the unfolded iPhone Duo in landscape (iOS 27.1+) the system moves
/// the toolbar into a vertical bar along the trailing edge, in the status
/// column (see `\.toolbarVerticalEdge`): the back button, each screen's
/// toolbar items and the tabs stack there, lined up under the clock and
/// battery, as in Apple's own apps. In portrait it is the usual bottom bar. A custom rail would duplicate that and fight it, so there isn't
/// one. Each section keeps its own navigation state, and the selected section
/// is in scene storage, so folding or unfolding keeps the user's place.
struct AdaptiveRoot: View {
    @SceneStorage("root.section") private var section: AppSection = .now

    var body: some View {
        TabView(selection: $section) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    section.content
                }
            }
        }
        #if DEBUG
            .onAppear {
                if let initial = LaunchOptions.initialSection { section = initial }
            }
            .overlay {
                if LaunchOptions.showsReservedRegions, #available(iOS 27.1, *) {
                    ReservedRegionOverlay()
                }
            }
        #endif
    }
}

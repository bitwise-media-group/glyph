// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import SwiftUI

/// A section's two panes.
///
/// At compact width they are one scrolling column. At regular width on iOS
/// 27.1 and later they go into SwiftUI's split `ArrangementView` with its
/// default behaviour: on the iPhone Duo, partially open, the system keeps the
/// panes clear of the crease itself; lying flat, content may cross the crease,
/// which reads as one continuous screen. Before iOS 27.1 regular width gets
/// two equal panes side by side.
///
/// Use it as the root of a section's NavigationStack — never inside a List
/// or ScrollView, and never around a NavigationSplitView.
struct SectionPanes<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var primary: Primary
    @ViewBuilder var secondary: Secondary

    var body: some View {
        if horizontalSizeClass == .compact {
            ScrollView {
                VStack {
                    primary
                    secondary
                }
                .padding()
            }
        } else if #available(iOS 27.1, *) {
            ArrangementView {
                Pane { primary }
            } secondary: {
                Pane { secondary }
            }
            .arrangementViewStyle(.split)
        } else {
            HStack(spacing: 0) {
                Pane { primary }
                Pane { secondary }
            }
        }
    }
}

/// One pane, with the system's standard padding. When its content fits it
/// doesn't scroll, and flexible content (the charts) takes the spare height;
/// otherwise it scrolls.
private struct Pane<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack { content }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ScrollView {
                VStack { content }
                    .padding()
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lays out children in a row when the panes are stacked (each pane is wide
/// and short), and in a column otherwise.
struct PaneStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 27.1, *) {
            SplitAxisStack { content }
        } else {
            VStack { content }
        }
    }
}

@available(iOS 27.1, *)
private struct SplitAxisStack<Content: View>: View {
    @Environment(\.splitArrangementAxis) private var axis
    @ViewBuilder var content: Content

    var body: some View {
        if axis == .vertical {
            HStack(alignment: .top) { content }
        } else {
            VStack { content }
        }
    }
}

/// A card, the building block of the panes: the system's `GroupBox`, so its
/// shape, padding and background follow the platform.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            if let title {
                Text(title).foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    /// Sizes a chart relative to its width when it scrolls (`aspectRatio` is
    /// width ÷ height), and lets it take any spare height when its pane has
    /// room — no fixed point sizes.
    func expandingHeight(aspectRatio: CGFloat) -> some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { self }
    }
}

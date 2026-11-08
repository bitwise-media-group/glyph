// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

#if DEBUG
    import SwiftUI

    /// Debug only: draws the scene's reserved regions over the app, the fold
    /// (`.division`) in red and occlusions such as the camera in blue, dashed
    /// when inactive, and prints the hinge state, the system's vertical
    /// toolbar edge and the container content margins.
    @available(iOS 27.1, *)
    struct ReservedRegionOverlay: View {
        @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge
        @State private var hinge = "no change yet"

        var body: some View {
            GeometryReader { proxy in
                let regions =
                    proxy.reservedRegions(kind: .division, options: .includeInactive)
                    + proxy.reservedRegions(kind: .occlusion, options: .includeInactive)
                ForEach(regions) { region in
                    let color: Color = region.kind == .division ? .red : .blue
                    Rectangle()
                        .stroke(color, style: StrokeStyle(lineWidth: 2, dash: region.isActive ? [] : [6, 4]))
                        .background(color.opacity(0.2))
                        .frame(width: max(region.frame.width, 4), height: max(region.frame.height, 4))
                        .position(x: region.frame.midX, y: region.frame.midY)
                }
                let margins = proxy.contentMargins(for: .container)
                Text(
                    """
                    hinge: \(hinge)
                    toolbarVerticalEdge: \(toolbarVerticalEdge.map { "\($0)" } ?? "nil")
                    container margins: t\(Int(margins.top)) l\(Int(margins.leading)) \
                    b\(Int(margins.bottom)) tr\(Int(margins.trailing))
                    """
                )
                .font(.caption.monospaced())
                .padding(6)
                .background(.yellow.opacity(0.85), in: .rect(cornerRadius: 6))
                .foregroundStyle(.black)
                .position(x: proxy.size.width / 2, y: proxy.size.height - 60)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onHingeChange { _, new in
                hinge = Self.describe(new)
            }
        }

        static func describe(_ context: DeviceHingeContext) -> String {
            guard let hinge = context.hinge else { return "none" }
            let status =
                switch hinge.status {
                case .closed: "closed"
                case .partiallyOpen: "partiallyOpen"
                case .fullyOpen: "fullyOpen"
                default: "other"
                }
            return "\(status) \(Int(hinge.angle.degrees))°"
        }
    }
#endif

//
//  ImmersiveView.swift
//  dayo...
//
//  Created by banjun on R 6/09/29.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var model = ImmersiveViewModel()

    var body: some View {
        RealityView { _ in
        } update: { content in
            if let arisu = model.arisu, arisu.parent == nil {
                content.add(arisu)

                arisu.transform = Transform(
                    rotation: .init(Rotation3D.identity
                        .rotated(by: .init(angle: .radians(.pi / 2), axis: .y))
                        .rotated(by: .init(angle: .radians(-.pi / 2), axis: .z))),
                    translation: .init(0, 0.03, 0))
                arisu.components.set(AnchoringComponent(.hand(.left, location: .palm), trackingMode: .predicted))
            }

            // below is correct, but the .predicted anchor above is better in performance
//            if let hand = model.activeHand {
//                var t = Transform(matrix: hand.originFromAnchorTransform)
//                let r = Rotation3D.identity
//                    .rotated(by: .init(angle: .radians(.pi / 2), axis: .y))
//                    .rotated(by: .init(angle: .radians(-.pi / 2), axis: .z))
//                    .rotated(by: Rotation3D(t.rotation))
//                t.rotation = .init(r)
//                let lift = Transform(translation: .init(-0.0, 0.08, -0.03))
//                model.arisu?.transform = Transform(matrix: t.matrix * lift.matrix)
//            }
        }
        .upperLimbVisibility(.hidden) // the model occludes hands
        .persistentSystemOverlays(.hidden) // disable home screen button on visionOS 2
        .task { await model.start() }
    }
}

import ARKit

@MainActor @Observable final class ImmersiveViewModel {
    var arisu: Entity!
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    var leftHand: HandAnchor?
    var rightHand: HandAnchor?
    var activeChirality: HandAnchor.Chirality = .left
    var activeHand: HandAnchor? {
        switch activeChirality {
        case .left: leftHand
        case .right: rightHand
        }
    }

    init() {
        Task {
            arisu = try! await Entity(named: "Immersive", in: realityKitContentBundle).findEntity(named: "arisu")!
        }
    }

    func start() async {
        guard HandTrackingProvider.isSupported else {
            NSLog("%@", "HandTrackingProvider.isSupported = \(HandTrackingProvider.isSupported)")
            return
        }

        do {
            NSLog("%@", "session is starting")
            try await session.run([handTracking])
            NSLog("%@", "session started")

            for await update in handTracking.anchorUpdates {
                switch update.event {
                case .added:
                    // NSLog("%@", "anchor added: \(update)")
                    break
                case .updated:
                    // NSLog("%@", "anchor updated: \(update)")
                    switch update.anchor.chirality {
                    case .left: leftHand = update.anchor
                    case .right: rightHand = update.anchor
                    }
                case .removed:
                    // NSLog("%@", "anchor removed: \(update)")
                    break
                }
            }
            NSLog("%@", "handTracking.anchorUpdates finished")
        } catch {
            NSLog("%@", "session.run error = \(String(describing: error))")
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}

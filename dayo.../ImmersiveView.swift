//
//  ImmersiveView.swift
//  dayo...
//
//  Created by banjun on R 6/09/29.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ObservableAnchorTrackingSystem

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(ImmersiveViewModel.self) private var model

    var body: some View {
        RealityView { content in
            content.add(ObservableAnchorTrackingSystem.createAnchorTargetEntities(anchorTargets: [
                .hand(.left, location: .joint(for: .littleFingerTip)),
                .hand(.left, location: .joint(for: .thumbTip)),
                .hand(.right, location: .palm),
                .hand(.right, location: .joint(for: .indexFingerKnuckle))
            ], withDebugAxes: false))

            let stageHeight: Float = 1.2
            let center = Entity()
            center.position = .init(0, stageHeight, -0.5)
            center.orientation = .init(angle: .pi, axis: .init(0, 1, 0))
            let stage = ModelEntity(mesh: .generateCylinder(height: stageHeight, radius: 0.2),
                                    materials: [SimpleMaterial(color: .black, roughness: 0.3, isMetallic: false)])
            stage.components.set(OpacityComponent(opacity: 0.95))
            stage.position.y = -stageHeight / 2
            stage.generateCollisionShapes(recursive: false, static: true)
            center.components.set(PhysicsSimulationComponent())
            stage.components.set(PhysicsBodyComponent(mode: .static))
            let arisu2Model = model.arisu2.findEntity(named: "Mesh") as! ModelEntity
            arisu2Model.generateCollisionShapes(recursive: false, static: true) // static?
            arisu2Model.components.set({
                var p = PhysicsBodyComponent(massProperties: .init(mass: 0.053), material: .generate(friction: 0, restitution: 1), mode: .dynamic)
                p.isAffectedByGravity = true
                p.isRotationLocked = (true, true, true)
                p.isTranslationLocked = (false, false, false)
                // p.linearDamping = 1
                // p.angularDamping = 1
                return p
            }())

            center.addChild(stage)
            center.addChild(model.arisu2)
            content.add(center)

            content.add(model.penLight)
        } update: { content in
            if let arisu = model.arisu, arisu.parent == nil {
                content.add(arisu)

                arisu.transform = Transform(
                    rotation: .init(Rotation3D.identity
                        .rotated(by: .init(angle: model.xRotation, axis: .x))
                        .rotated(by: .init(angle: .radians(.pi / 2), axis: .y))
                        .rotated(by: .init(angle: .radians(-.pi / 2) + model.zRotation, axis: .z))),
                    translation: .init(0, 0.03, 0))
                arisu.components.set(AnchoringComponent(.hand(.left, location: .palm), trackingMode: .predicted))
            }
            if let skyDome = model.skyDome, skyDome.parent == nil {
                content.add(skyDome)
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
            let handAnchors = ObservableAnchorTrackingSystem.observable.transforms
            if let palm = handAnchors[.hand(.right, location: .palm)],
               let indexFingerKnuckle = handAnchors[.hand(.right, location: .joint(for: .indexFingerKnuckle))] {
                var t = palm
                t.translation += t.rotation.act(.init(0, 0.03, 0)) // +y is back->palm, for right hand palm anchor
                t.rotation = .init(angle: .pi / 8, axis: .init(1, 0.5, -0.1)) * t.rotation // small adjust
                t.rotation = .init(from: t.rotation.act(.init(0, 1, 0)), to: normalize(indexFingerKnuckle.translation - palm.translation)) * t.rotation
                model.penLight.transform = t
            }
        }
        .upperLimbVisibility(model.upperLimbVisibility) // the model occludes hands
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

    var skyDome: Entity!
    var showsSkyDome: Bool = false {
        didSet {skyDome.isEnabled = showsSkyDome}
    }

    var upperLimbVisibility: Visibility = .automatic

    var xRotation: Angle2D = .radians(-.pi / 6) // .radians(.pi / 2)
    var zRotation: Angle2D = .radians(-.pi / 4)

    var arisu2: Entity!
    var penLight: PenLight!

    init() async {
        arisu = try! await Entity(named: "Immersive", in: realityKitContentBundle).findEntity(named: "arisu")!
        skyDome = try! await Entity(named: "SkyDome")
        skyDome.isEnabled = false
        try! await setupJoints()
        arisu2 = arisu.clone(recursive: true)
        arisu.findEntity(named: "Mesh")!.components.set(HandPuppetComponent())
        arisu2.findEntity(named: "Mesh")!.components.set(HandTouchComponent())

        penLight = PenLight()
        penLight.components.set(ModelSortGroupComponent(group: .planarUIAlwaysInFront, order: 0))
    }

    func start() async {
        guard HandTrackingProvider.isSupported else {
            NSLog("%@", "HandTrackingProvider.isSupported = \(HandTrackingProvider.isSupported)")
            return
        }
        ObservableAnchorTrackingSystem.registerSystem()
        HandPuppetIKSystem.registerSystem()
        HandTouchIKSystem.registerSystem()
    }

    func setupJoints() async throws {
        guard let arisu else { return }

        let modelEntity = (arisu.findEntity(named: "Mesh") as! ModelEntity)
        let model = modelEntity.model!
        let jointsRoot = arisu.findEntity(named: "joints")!
        let hip = jointsRoot.findEntity(named: "hip")!
        let chest = jointsRoot.findEntity(named: "chest")!
        let neck = jointsRoot.findEntity(named: "neck")!
        let head = jointsRoot.findEntity(named: "head")!
        let L_cheek = jointsRoot.findEntity(named: "L_cheek")!
        let R_cheek = jointsRoot.findEntity(named: "R_cheek")!
        let L_clavicle = jointsRoot.findEntity(named: "L_clavicle")!
        let L_shoulder = jointsRoot.findEntity(named: "L_shoulder")!
        let L_elbow = jointsRoot.findEntity(named: "L_elbow")!
        let L_wrist = jointsRoot.findEntity(named: "L_wrist")!
        let R_clavicle = jointsRoot.findEntity(named: "R_clavicle")!
        let R_shoulder = jointsRoot.findEntity(named: "R_shoulder")!
        let R_elbow = jointsRoot.findEntity(named: "R_elbow")!
        let R_wrist = jointsRoot.findEntity(named: "R_wrist")!
        let L_hipbone = jointsRoot.findEntity(named: "L_hipbone")!
        let R_hipbone = jointsRoot.findEntity(named: "R_hipbone")!

        let skeletonID = "skeleton1"
        // order should match meshResourceContents.skeletons order
        let joints: [Entity] = [jointsRoot, hip, chest, neck, head, L_cheek, R_cheek, L_clavicle, L_shoulder, L_elbow, L_wrist, R_clavicle, R_shoulder, R_elbow, R_wrist, L_hipbone, R_hipbone]

        nonisolated(unsafe) var meshResourceContents = model.mesh.contents
        meshResourceContents.models = [{
            var model = meshResourceContents.models[0]
            var part = model.parts[0]
            part.skeletonID = skeletonID
            let jointPosisions = joints.map {$0.convert(position: .zero, to: jointsRoot)}.enumerated()
            let influences: [Int] = part.positions.elements.map { p in
                jointPosisions.min {distance_squared(p, $0.element) < distance_squared(p, $1.element)}!.offset
            }
            part.jointInfluences = .init(influences: MeshBuffers.JointInfluences(influences.map {.init(jointIndex: $0, weight: 1)}), influencesPerVertex: 1)
            model.parts = [part]
            return model
        }()]
        meshResourceContents.skeletons = [MeshResource.Skeleton(id: skeletonID, joints: [
            .init(name: jointsRoot.name,
                  parentIndex: nil,
                  inverseBindPoseMatrix: jointsRoot.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: .identity),
            .init(name: hip.name,
                  parentIndex: joints.firstIndex(of: jointsRoot)!,
                  inverseBindPoseMatrix: hip.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: hip.convert(transform: .identity, to: jointsRoot)),
            .init(name: chest.name,
                  parentIndex: joints.firstIndex(of: hip)!,
                  inverseBindPoseMatrix: chest.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: chest.convert(transform: .identity, to: hip)),
            .init(name: neck.name,
                  parentIndex: joints.firstIndex(of: chest)!,
                  inverseBindPoseMatrix: neck.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: neck.convert(transform: .identity, to: chest)),
            .init(name: head.name,
                  parentIndex: joints.firstIndex(of: neck)!,
                  inverseBindPoseMatrix: head.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: head.convert(transform: .identity, to: neck)),
            .init(name: L_cheek.name,
                  parentIndex: joints.firstIndex(of: head)!,
                  inverseBindPoseMatrix: L_cheek.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: L_cheek.convert(transform: .identity, to: head)),
            .init(name: R_cheek.name,
                  parentIndex: joints.firstIndex(of: head)!,
                  inverseBindPoseMatrix: R_cheek.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: R_cheek.convert(transform: .identity, to: head)),
            .init(name: L_clavicle.name,
                  parentIndex: joints.firstIndex(of: chest)!,
                  inverseBindPoseMatrix: L_clavicle.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: L_clavicle.convert(transform: .identity, to: chest)),
            .init(name: L_shoulder.name,
                  parentIndex: joints.firstIndex(of: L_clavicle)!,
                  inverseBindPoseMatrix: L_shoulder.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: L_shoulder.convert(transform: .identity, to: L_clavicle)),
            .init(name: L_elbow.name,
                  parentIndex: joints.firstIndex(of: L_shoulder)!,
                  inverseBindPoseMatrix: L_elbow.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: L_elbow.convert(transform: .identity, to: L_shoulder)),
            .init(name: L_wrist.name,
                  parentIndex: joints.firstIndex(of: L_elbow)!,
                  inverseBindPoseMatrix: L_wrist.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: L_wrist.convert(transform: .identity, to: L_elbow)),
            .init(name: R_clavicle.name,
                  parentIndex: joints.firstIndex(of: chest)!,
                  inverseBindPoseMatrix: R_clavicle.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: R_clavicle.convert(transform: .identity, to: chest)),
            .init(name: R_shoulder.name,
                  parentIndex: joints.firstIndex(of: R_clavicle)!,
                  inverseBindPoseMatrix: R_shoulder.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: R_shoulder.convert(transform: .identity, to: R_clavicle)),
            .init(name: R_elbow.name,
                  parentIndex: joints.firstIndex(of: R_shoulder)!,
                  inverseBindPoseMatrix: R_elbow.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: R_elbow.convert(transform: .identity, to: R_shoulder)),
            .init(name: R_wrist.name,
                  parentIndex: joints.firstIndex(of: R_elbow)!,
                  inverseBindPoseMatrix: R_wrist.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: R_wrist.convert(transform: .identity, to: R_elbow)),
            .init(name: L_hipbone.name,
                  parentIndex: joints.firstIndex(of: hip)!,
                  inverseBindPoseMatrix: L_hipbone.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: L_hipbone.convert(transform: .identity, to: hip)),
            .init(name: R_hipbone.name,
                  parentIndex: joints.firstIndex(of: hip)!,
                  inverseBindPoseMatrix: R_hipbone.convert(transform: .identity, to: modelEntity).matrix.inverse,
                  restPoseTransform: R_hipbone.convert(transform: .identity, to: hip)),
        ])]

        let r = try await MeshResource(from: meshResourceContents)
        modelEntity.model!.mesh = r
        // NSLog("%@", "SkeletalPosesComponent = \(String(describing: modelEntity.components[SkeletalPosesComponent.self]))")

        let skeleton = modelEntity.model!.mesh.contents.skeletons[0]
        var rig = try IKRig(for: skeleton)
        rig.maxIterations = 30
        rig.globalFkWeight = 0.1
        rig.constraints = [
            .point(named: "L_wrist", on: "L_wrist",
                   positionWeight: .init(repeating: 1)),
            .point(named: "R_wrist", on: "R_wrist",
                   positionWeight: .init(repeating: 1)),
        ]

        // fixed joint influences
        rig.joints["hip"]!.limits = .init(weight: 2)
        rig.joints["chest"]!.limits = .init(weight: 2)
        rig.joints["neck"]!.limits = .init(weight: 2)
        rig.joints["head"]!.limits = .init(weight: 2)
        rig.joints["L_clavicle"]!.limits = .init(weight: 100)
        rig.joints["R_clavicle"]!.limits = .init(weight: 100)
        rig.joints["L_cheek"]!.limits = .init(weight: 100)
        rig.joints["R_cheek"]!.limits = .init(weight: 100)
        rig.joints["L_hipbone"]!.limits = .init(weight: 5)
        rig.joints["R_hipbone"]!.limits = .init(weight: 5)

        let resource = try IKResource(rig: rig)
        modelEntity.components.set(IKComponent(resource: resource))
    }
}

struct HandPuppetComponent: Component {}

import ObservableAnchorTrackingSystem
struct HandPuppetIKSystem: System {
    static let query: EntityQuery = .init(where: .has(HandPuppetComponent.self) && .has(IKComponent.self))
    static var dependencies: [SystemDependency] = [.after(ObservableAnchorTrackingSystem.self)]
    init(scene: RealityKit.Scene) {}
    func update(context: SceneUpdateContext) {
        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { e in
            let ik = e.components[IKComponent.self]!
            guard let solver = ik.solvers.first else { return }

            let transforms = ObservableAnchorTrackingSystem.observable.transforms

            if let c = solver.constraints["L_wrist"], let t = transforms[.hand(.left, location: .joint(for: .littleFingerTip))] {
                c.target = e.convert(transform: t, from: nil)
                c.animationOverrideWeight = (1, 1)
            }
            if let c = solver.constraints["R_wrist"], let t = transforms[.hand(.left, location: .joint(for: .thumbTip))] {
                c.target = e.convert(transform: t, from: nil)
                c.animationOverrideWeight = (1, 1)
            }
            e.components.set(ik)
        }
    }
}

struct HandTouchComponent: Component {
    var lastJump: Date?
}
struct HandTouchIKSystem: System {
    static let query: EntityQuery = .init(where: .has(HandTouchComponent.self) && .has(IKComponent.self))
    static var dependencies: [SystemDependency] = [.after(ObservableAnchorTrackingSystem.self)]
    init(scene: RealityKit.Scene) {}
    func update(context: SceneUpdateContext) {
        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { e in
            let ik = e.components[IKComponent.self]!
            var touch = e.components[HandTouchComponent.self]!
            guard let solver = ik.solvers.first else { return }
            guard case let p as HasPhysicsBody = e else { return }
            guard let joints = (e as? ModelEntity)?.model?.mesh.contents.skeletons[0].joints else { return }

            let transforms = ObservableAnchorTrackingSystem.observable.transforms

            if let c = solver.constraints["L_wrist"], let t = transforms[.hand(.right, location: .palm)] {
                let tInE = e.convert(transform: t, from: nil)
                let distance = distance(tInE.translation, .init(-0.05, 0.12, -0.07))
                let zDistance = abs(tInE.translation.z + 0.07)

                let mass: Float = 0.053 // match to PhysicsBody mass
                let impulse: Float = 0.09  // >= 0.13 Ns cause bounce
                let g: Float = 9.81
                let duration: Float = 2 * impulse / mass / g
                let elapsedFromLastJump = touch.lastJump.map { Date().timeIntervalSince($0) }
                let bind = Transform(matrix: joints.first {$0.name == "L_wrist"}!.inverseBindPoseMatrix.inverse)

                if distance < 0.1 && zDistance < 0.02 {
                    if let elapsedFromLastJump, elapsedFromLastJump < Double(duration) {
                        // cool, refrain from another jump
                    } else {
                        solver.globalFkWeight = 0.1
                        p.applyLinearImpulse(.init(0, impulse, 0), relativeTo: nil)
                        touch.lastJump = Date()

                        c.target = tInE
                        c.target.translation.z -= 0.03
                        c.animationOverrideWeight = (1, 0)
                    }
                } else {
                    if let elapsedFromLastJump, elapsedFromLastJump > Double(duration / 2) {
                        solver.globalFkWeight = 0.8
                        c.target = bind
                        c.animationOverrideWeight = (0.2, 0)
                    }
                    if let elapsedFromLastJump, elapsedFromLastJump > Double(duration) {
                        solver.globalFkWeight = 0.8
                        c.animationOverrideWeight = (0, 0)
                    }
                }
                // c.animationOverrideWeight = (max(0, exp(-2 * (distance * zDistance)) - 0.2), 0.1)
            }
            if let c = solver.constraints["R_wrist"], let t = transforms[.hand(.right, location: .palm)] {
//                c.target = e.convert(transform: t, from: nil)
//                c.target.translation.y = max(0, c.target.translation.y)
//                let distance = distance(c.target.translation, .zero)
//                let zDistance = abs(c.target.translation.z)
//                c.animationOverrideWeight = (max(0, exp(-2 * (distance * zDistance)) - 0.2), 0.1)
            }
            ["hip", "chest", "neck", "head"].forEach { j in
                if let c = solver.constraints[j] {
                    c.target = Transform(matrix: joints.first {$0.name == j}!.inverseBindPoseMatrix.inverse)
                    c.animationOverrideWeight = (1, 1)
                }
            }
            e.components.set(ik)
            e.components.set(touch)
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}

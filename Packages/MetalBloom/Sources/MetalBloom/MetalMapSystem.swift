import RealityKit

public struct MetalMapSystem: System {
    public struct Component: RealityKit.Component {
        public var map: MetalMap?
        public init(map: MetalMap? = nil) {
            self.map = map
        }
    }
    public init(scene: Scene) {
    }
    public func update(context: SceneUpdateContext) {
        for e in context.entities(matching: .init(where: .has(Component.self)), updatingSystemWhen: .rendering) {
            let c = e.components[Component.self]!
            guard let map = c.map else { continue }
            map.draw(e)
            return
        }
    }
}

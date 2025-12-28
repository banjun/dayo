import RealityKit
import RCPMaterialParameters
import CoreGraphics

final class PenLight: Entity {
    required init() {
        super.init()
        addChild(try! Entity.load(named: "PenLight"))
    }
    var head: ModelEntity! {findEntity(named: "Head")?.children.first as? ModelEntity}
    var body: Entity! {findEntity(named: "Body")}
    var color: CGColor {
        get{head.shaderGraphMaterial.getByVarName()}
        set {
            try! head.shaderGraphMaterial.setByVarName(newValue)
            try! body.recursiveModelEntities.forEach {try $0.shaderGraphMaterial.setByVarName(newValue)}
        }
    }
}

extension Entity {
    var recursiveModelEntities: [ModelEntity] {
        [self as? ModelEntity].compactMap {$0} + children.flatMap(\.recursiveModelEntities)
    }
}


import ShaderGraphCoder
import RealityKit

public extension ShaderGraphMaterial {
    static func screenCoordinateMaterial(texture: TextureResource, uniforms: TextureResource) async -> ShaderGraphMaterial {
        let mapValue = SGColor.projectedMap(textureArray: .texture(texture), uv: SGVector.screenUV(uniformsTextureResource: uniforms))
        var m = try! await ShaderGraphMaterial(surface: unlitSurface(color: mapValue.rgb, opacity: .zero, applyPostProcessToneMap: false, hasPremultipliedAlpha: true))
        m.faceCulling = .front
        return m
    }
}

import ShaderGraphCoder
import RealityKit

public extension SGVector {
    static func screenUV(uniformsTextureResource: TextureResource) -> SGVector {
        // decode CameraTransform & projection matrices from texture in 4x3 pixels. each row encodes 1 matrix.
        let uniforms = SGTexture.texture(uniformsTextureResource)
        let cameraTransformL = SGMatrix.decodeTexturePixel(texture: uniforms, offset: .vector2f(0, 0))
        let cameraTransformR = SGMatrix.decodeTexturePixel(texture: uniforms, offset: .vector2f(0, 1))
        let cameraProjection0 = SGMatrix.decodeTexturePixel(texture: uniforms, offset: .vector2f(0, 2))
        let cameraProjection1 = SGMatrix.decodeTexturePixel(texture: uniforms, offset: .vector2f(0, 3))
        return .screenUV(cameraTransformL: cameraTransformL, cameraTransformR: cameraTransformR, cameraProjection0: cameraProjection0, cameraProjection1: cameraProjection1)
    }
}

extension SGVector {
    static func screenUV(cameraTransformL: SGMatrix, cameraTransformR: SGMatrix, cameraProjection0: SGMatrix, cameraProjection1: SGMatrix) -> SGVector {
        let viewDirection = SGVector.viewDirection(space: .world)
        let viewDirection4 = SGVector.vector4f(viewDirection.x, viewDirection.y, viewDirection.z, .float(0))

        let viewDirectionInViewBackL = viewDirection4.transformMatrix(mat: cameraTransformL.invertMatrix()).xyz
        let viewDirectionInViewBackR = viewDirection4.transformMatrix(mat: cameraTransformR.invertMatrix()).xyz

        let z_proj = SGScalar.float(-1.0)
        let pViewL = viewDirectionInViewBackL * (z_proj / viewDirectionInViewBackL.z)
        let pViewR = viewDirectionInViewBackR * (z_proj / viewDirectionInViewBackR.z)
        let pView4L = SGVector.vector4f(pViewL.x, pViewL.y, pViewL.z, .float(1))
        let pView4R = SGVector.vector4f(pViewR.x, pViewR.y, pViewR.z, .float(1))
        let ndc4 = ShaderGraphCoder.geometrySwitchCameraIndex(
            mono: pView4L.transformMatrix(mat: cameraProjection0),
            left: pView4L.transformMatrix(mat: cameraProjection0),
            right: pView4R.transformMatrix(mat: cameraProjection1),
        )
        let ndc = ndc4.xy / ndc4.w
        let uv = (ndc + 1) / 2
        return uv
    }
}
extension SGMatrix {
    static func decodeTexturePixel(texture: SGTexture, offset: SGVector, stride: SGVector = .vector2f(1, 0)) -> SGMatrix {
        .matrix4d(
            SGVector.decodeTexturePixel(texture: texture, texcoord: offset + stride * 0),
            SGVector.decodeTexturePixel(texture: texture, texcoord: offset + stride * 1),
            SGVector.decodeTexturePixel(texture: texture, texcoord: offset + stride * 2),
            SGVector.decodeTexturePixel(texture: texture, texcoord: offset + stride * 3),
        )
    }
}
extension SGVector {
    static func decodeTexturePixel(texture: SGTexture, defaultValue: SGVector = .vector4fZero, texcoord: SGVector) -> SGVector {
        texture.pixel(filter: .nearest, defaultValue: defaultValue, texcoord: texcoord)
    }
}

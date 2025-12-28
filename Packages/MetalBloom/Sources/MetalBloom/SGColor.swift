import ShaderGraphCoder

public extension SGColor {
    static func projectedMap(textureArray: SGTexture, uv: SGVector) -> SGColor {
        let image: (Int) -> SGColor = {
            textureArray.image2DArrayColor4(index: .int($0), defaultValue: .transparentBlack, texcoord: uv, magFilter: .linear, minFilter: .linear, uWrapMode: .clampToEdge, vWrapMode: .clampToEdge, noFlipV: .int(1))
        }
        return ShaderGraphCoder.geometrySwitchCameraIndex(mono: image(0), left: image(0), right: image(1))
    }
}

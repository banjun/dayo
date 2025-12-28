import ShaderGraphCoder

extension SGTexture {
    func image2DArrayColor4(index: SGValue = .int(0), defaultValue: SGColor, texcoord: SGVector? = nil, magFilter: SGSamplerMinMagFilter = SGSamplerMinMagFilter.linear, minFilter: SGSamplerMinMagFilter = SGSamplerMinMagFilter.linear, uWrapMode: SGSamplerAddressMode = SGSamplerAddressMode.clampToEdge, vWrapMode: SGSamplerAddressMode = SGSamplerAddressMode.clampToEdge, noFlipV: SGValue = .int(0)) -> SGColor {
        SGColor(source: .nodeOutput(SGNode(
            nodeType: "ND_RealityKitTexture2DArray_color4",
            inputs: [
                .init(name: "file", dataType: SGDataType.asset, connection: self),
                .init(name: "u_wrap_mode", dataType: SGDataType.string, connection: SGString(source: .constant(.string(uWrapMode.rawValue)))),
                .init(name: "v_wrap_mode", dataType: SGDataType.string, connection: SGString(source: .constant(.string(vWrapMode.rawValue)))),
                .init(name: "mag_filter", dataType: SGDataType.string, connection: SGString(source: .constant(.string(magFilter.rawValue)))),
                .init(name: "min_filter", dataType: SGDataType.string, connection: SGString(source: .constant(.string(minFilter.rawValue)))),
                .init(name: "default", dataType: SGDataType.color4f, connection: defaultValue),
                .init(name: "texcoord", dataType: SGDataType.vector2f, connection: texcoord),
                .init(name: "index", dataType: SGDataType.int, connection: index),
                .init(name: "no_flip_v", dataType: SGDataType.bool, connection: noFlipV),
            ],
            outputs: [.init(dataType: SGDataType.color4f)])))
    }
}


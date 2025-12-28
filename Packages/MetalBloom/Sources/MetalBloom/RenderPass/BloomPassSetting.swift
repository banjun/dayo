import Metal

class BloomPassSetting {
    let state: MTLRenderPipelineState
    let descriptorAndOutTextures: [(MTLRenderPassDescriptor, any MTLTexture)] // for ping-pong, i.e. loop over in->0->1->0->1...and then the last tex is final output (depends on loop length)
    let kawaseBlurOffsets: [SIMD2<Float>] = [1, 2, 4, 8, 16, 32]
        .map {$0 / 1024 / 4 / .init(1, DeviceDependants.aspectRatio)}

    convenience init(device: any MTLDevice, width: Int, height: Int, pixelFormat: MTLPixelFormat, viewCount: Int) {
        self.init(device: device,
                  outTextures: [
                    RenderPassEncoderSettings.makeTexture(device: device, width: width, height: height, pixelFormat: pixelFormat, viewCount: viewCount),
                    RenderPassEncoderSettings.makeTexture(device: device, width: width, height: height, pixelFormat: pixelFormat, viewCount: viewCount),
                  ])
    }
    init(device: any MTLDevice, outTextures: [any MTLTexture]) {
        state = RenderPassEncoderSettings.makeRenderPipelineState(device: device, fragmentFunction: "bloom_fragment", pixelFormat: outTextures[0].pixelFormat)
        descriptorAndOutTextures = outTextures.map {(RenderPassEncoderSettings.renderPassDescriptor(texture: $0), $0)}
    }

    func encode(in commandBuffer: any MTLCommandBuffer, inTexture: any MTLTexture) -> any MTLTexture {
        var nextTexture = inTexture
        for (i, kawaseBlurOffset) in kawaseBlurOffsets.enumerated() {
            let (descriptor, outTexture) = descriptorAndOutTextures[i % descriptorAndOutTextures.count]
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { continue }
            defer {encoder.endEncoding()}
            encoder.setRenderPipelineState(state)

            var kawaseOffset = kawaseBlurOffset
            encoder.setFragmentBytes(&kawaseOffset, length: MemoryLayout.stride(ofValue: kawaseOffset), index: 0)

            [nextTexture].enumerated().forEach { i, t in
                encoder.setFragmentTexture(t, index: i)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: outTexture.arrayLength)

            nextTexture = outTexture
        }
        return nextTexture
    }
}

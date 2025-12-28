import Metal

class CopyPassSetting {
    let state: MTLRenderPipelineState
    let descriptor: MTLRenderPassDescriptor
    let outTexture: any MTLTexture

    init(device: any MTLDevice, outTexture: any MTLTexture) {
        state = RenderPassEncoderSettings.makeRenderPipelineState(device: device, fragmentFunction: "copy", pixelFormat: outTexture.pixelFormat)
        descriptor = RenderPassEncoderSettings.renderPassDescriptor(texture: outTexture)
        self.outTexture = outTexture
    }

    func encode(in commandBuffer: any MTLCommandBuffer, inTexture: any MTLTexture) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        defer {encoder.endEncoding()}
        encoder.setRenderPipelineState(state)

        [inTexture].enumerated().forEach { i, inTexture in
            encoder.setFragmentTexture(inTexture, index: i)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: outTexture.arrayLength)
    }
}

import Metal
import RealityKit
import MetalBloomBridgingHeader

class ScenePassSetting {
    private let device: any MTLDevice
    private(set) var state: MTLRenderPipelineState?
    let descriptor: MTLRenderPassDescriptor
    @MainActor var llMesh: LowLevelMesh? {
        didSet {createState()}
    }
    let outTexture: any MTLTexture
    let depthTexture: any MTLTexture
    let depthStencilState: MTLDepthStencilState
    private var materialTextureCache: [Entity.ID: MTLTexture] = [:]

    convenience init(device: any MTLDevice, width: Int, height: Int, pixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat = .depth16Unorm, viewCount: Int) {
        #if DEBUG
        let usage: MTLTextureUsage = [.renderTarget, .shaderRead] // .shaderRead is just for debug. not needed for production
        #else
        let usage: MTLTextureUsage = [.renderTarget]
        #endif
        self.init(device: device,
                  outTexture: RenderPassEncoderSettings.makeTexture(device: device, width: width, height: height, pixelFormat: pixelFormat, viewCount: viewCount),
                  depthTexture: RenderPassEncoderSettings.makeTexture(device: device, width: width, height: height, pixelFormat: depthPixelFormat, usage: usage, viewCount: viewCount))
    }
    init(device: any MTLDevice, outTexture: any MTLTexture, depthTexture: any MTLTexture) {
        self.device = device
        descriptor = RenderPassEncoderSettings.renderPassDescriptor(texture: outTexture, depthTexture: depthTexture)
        self.outTexture = outTexture
        self.depthTexture = depthTexture
        depthStencilState = device.makeDepthStencilState(descriptor: {
            let d = MTLDepthStencilDescriptor()
            d.isDepthWriteEnabled = true
            d.depthCompareFunction = .greaterEqual
            return d
        }())!
    }

    @MainActor func createState() {
        state = llMesh.map {RenderPassEncoderSettings.makeRenderPipelineState(device: device, vertexFunction: "render_vertex", fragmentFunction: "render_fragment", llMesh: $0, pixelFormat: outTexture.pixelFormat, depthPixelFormat: depthTexture.pixelFormat)}
    }

    @MainActor func encode(in commandBuffer: any MTLCommandBuffer, cameraTransformAndProjections: [(transform: simd_float4x4, projection: simd_float4x4)], entity: Entity) {
        guard let llMesh, let state, let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        defer {encoder.endEncoding()}
        encoder.setRenderPipelineState(state)

        var vertexUniforms: [VertexUniforms] = cameraTransformAndProjections.map {
            VertexUniforms(modelTransform: entity.convert(transform: entity.transform, to: nil).matrix,
                           cameraTransform: $0.transform,
                           cameraTransformInverse: $0.transform.inverse,
                           projection: $0.projection,
                           projectionInverse: $0.projection.inverse)
        }
        var fragmentUniforms: FragmentUniforms = .init(textureSize: .init(Int32(outTexture.width), Int32(outTexture.height)))

        encoder.setVertexBuffer(llMesh.read(bufferIndex: 0, using: commandBuffer), offset: 0, index: 0)
        encoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.stride * vertexUniforms.count, index: 1)
        encoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 2)
        let materials = (entity as? ModelEntity)?.model!.materials ?? []
        if let tex = materialTextureCache[entity.id] {
            encoder.setFragmentTexture(tex, index: 0)
            encoder.setDepthStencilState(depthStencilState)
            encoder.setCullMode(.back) // just for performance, requires front facing = ccw (below)
            encoder.setFrontFacing(.counterClockwise)
        } else if let baseColorTexture = (
            materials.compactMap {($0 as? PhysicallyBasedMaterial)}.first?.baseColor.texture
            ?? materials.compactMap {$0 as? UnlitMaterial}.first?.color.texture) {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: baseColorTexture.resource.pixelFormat, width: baseColorTexture.resource.width, height: baseColorTexture.resource.height, mipmapped: baseColorTexture.resource.mipmapLevelCount > 1)
            desc.storageMode = .private
            desc.usage = [.shaderRead, .shaderWrite]
            let tex = state.device.makeTexture(descriptor: desc)!
            try! baseColorTexture.resource.copy(to: tex)
            materialTextureCache[entity.id] = tex
        }

        encoder.drawIndexedPrimitives(type: .triangle, indexCount: llMesh.parts.reduce(into: 0) {$0 += $1.indexCount}, indexType: .uint32, indexBuffer: llMesh.readIndices(using: commandBuffer), indexBufferOffset: 0, instanceCount: vertexUniforms.count) // instanceCount: 2 for left/right projection (view id)
    }
}

import Metal
import RealityKit

enum RenderPassEncoderSettings {
    static func makeTexture(device: any MTLDevice, width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: MTLTextureUsage = [.renderTarget, .shaderRead], viewCount: Int) -> any MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        d.usage = usage
        d.storageMode = .private // for store for the next pass. (.memoryless cannot be stored)
        d.textureType = .type2DArray // for left/right
        d.arrayLength = viewCount
        return device.makeTexture(descriptor: d)!
    }

    static func makeRenderPipelineState(device: any MTLDevice, library: (any MTLLibrary)? = nil, vertexFunction: String = "fullscreen_vertex", fragmentFunction: String, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let library = library ?? device.makeBundleDebugLibrary()!
        let d = MTLRenderPipelineDescriptor()
        d.inputPrimitiveTopology = .triangle
        d.vertexFunction = library.makeFunction(name: vertexFunction)!
        d.fragmentFunction = library.makeFunction(name: fragmentFunction)!
        d.colorAttachments[0].pixelFormat = pixelFormat
        return try! device.makeRenderPipelineState(descriptor: d)
    }

    @MainActor static func makeRenderPipelineState(device: any MTLDevice, library: (any MTLLibrary)? = nil, vertexFunction: String, fragmentFunction: String, llMesh: LowLevelMesh, pixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let library = library ?? device.makeBundleDebugLibrary()!
        let llDescriptor = llMesh.descriptor

        let d = MTLRenderPipelineDescriptor()
        d.inputPrimitiveTopology = .triangle
        d.rasterSampleCount = 1
        d.vertexFunction = library.makeFunction(name: vertexFunction)!
        d.vertexDescriptor = .init()
        llDescriptor.vertexLayouts.enumerated().forEach { i, l in
            d.vertexDescriptor!.layouts[i]!.stride = l.bufferStride
        }
        let vertexAttributes: [LowLevelMesh.Attribute] = llDescriptor.vertexAttributes
        vertexAttributes.enumerated().forEach { i, a in
            d.vertexDescriptor!.attributes[i]!.format = a.format
            d.vertexDescriptor!.attributes[i]!.offset = a.offset
            d.vertexDescriptor!.attributes[i]!.bufferIndex = a.layoutIndex
        }
        d.fragmentFunction = library.makeFunction(name: fragmentFunction)!
        d.colorAttachments[0].pixelFormat = pixelFormat
        d.depthAttachmentPixelFormat = depthPixelFormat
        return try! device.makeRenderPipelineState(descriptor: d)
    }

    static func renderPassDescriptor(texture: any MTLTexture, clearColor: MTLClearColor = .init(red: 0, green: 0, blue: 0, alpha: 0), loadAction: MTLLoadAction = .clear, storeAction: MTLStoreAction = .store, depthTexture: (any MTLTexture)? = nil) -> MTLRenderPassDescriptor {
        let d = MTLRenderPassDescriptor()
        d.renderTargetArrayLength = texture.arrayLength
        d.colorAttachments[0]?.texture = texture
        d.colorAttachments[0]?.clearColor = clearColor
        d.colorAttachments[0]?.loadAction = loadAction
        d.colorAttachments[0]?.storeAction = storeAction
        if let depthTexture {
            d.depthAttachment.texture = depthTexture
            d.depthAttachment.loadAction = .clear
#if DEBUG
            d.depthAttachment.storeAction = .store
#else
            d.depthAttachment.storeAction = .dontCare
#endif
            d.depthAttachment.clearDepth = 0
        }
        return d
    }
}

import Metal
import RealityKit
import ARKit
import QuartzCore
import Observation
import MetalBloomBridgingHeader

@Observable
public final class MetalMap {
    private let commandQueue: MTLCommandQueue
    private let llTexture: LowLevelTexture // type2DArray, [left, right]
    public let textureResource: TextureResource // type2DArray, [left, right]
    private let uniformsTexture: LowLevelTexture
    private let uniformsMetalTexture: MTLTexture
    private let uniformsBuffer: any MTLBuffer
    public let uniformsTextureResource: TextureResource

    // scene -> post effects (bright, bloom) -> composite -> llTexture -> textureResource
    private let scenePass: ScenePassSetting
    @MainActor public var llMesh: LowLevelMesh? {
        get {scenePass.llMesh}
        set {scenePass.llMesh = newValue}
    }
    private let brightPass: BrightPassSetting
    private let bloomPass: BloomPassSetting
    private let compositePass: CompositePassSetting

    private var arkitSession: ARKitSession? {
        didSet {oldValue?.stop()}
    }
    private var worldTracker: WorldTrackingProvider?

    private let debugLLTexture: LowLevelTexture
    private let debugMetalTexture: any MTLTexture
    public let debugTextureResource: TextureResource
    public var debugBlit: DebugBlit?
    public enum DebugBlit: String, Hashable, Identifiable, CaseIterable {
        case scene, depth, bright, bloom, composite
        public var id: String {rawValue}
    }
    private let copyPass: CopyPassSetting
    private let depthToColorPass: DepthToColorPassSetting

    @MainActor public init(device: MTLDevice = MTLCreateSystemDefaultDevice()!, pixelFormat: MTLPixelFormat = .rgba16Float, width: Int = 32, height: Int = 32, viewCount: Int = DeviceDependants.viewCount) {
        commandQueue = device.makeCommandQueue()!

        llTexture = try! LowLevelTexture(descriptor: .init(textureType: .type2DArray, pixelFormat: pixelFormat, width: width, height: height, arrayLength: viewCount, textureUsage: [.renderTarget])) // arrayLength: 2 for left/right eye
        textureResource = try! .init(from: llTexture)

        uniformsTexture = try! LowLevelTexture(descriptor: .init(pixelFormat: .rgba32Float, width: 4, height: 5)) // rgba for 1 row of simd_float4x4, total simd_float4x4 is rgba x 4, thus width = 4, and height 4 for camera center, transformL, transformR, projection0, projection1.
        uniformsMetalTexture = uniformsTexture.read()
        uniformsTextureResource = try! .init(from: uniformsTexture)
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size * 5)!

        scenePass = .init(device: device, width: width, height: height, pixelFormat: pixelFormat, viewCount: viewCount)
        brightPass = .init(device: device, width: width / 2, height: height / 2, pixelFormat: pixelFormat, viewCount: viewCount)
        bloomPass = .init(device: device, width: width / 4, height: height / 4, pixelFormat: pixelFormat, viewCount: viewCount)
        compositePass = .init(device: device, outTexture: llTexture.read())

        debugLLTexture = try! LowLevelTexture(descriptor: .init(textureType: .type2DArray, pixelFormat: pixelFormat, width: width, height: height, arrayLength: viewCount, textureUsage: []))
        debugMetalTexture = debugLLTexture.read()
        debugTextureResource = try! .init(from: debugLLTexture)
        copyPass = .init(device: device, outTexture: debugMetalTexture)
        depthToColorPass = .init(device: device, outTexture: debugMetalTexture)
    }

    @MainActor func draw(_ entity: Entity) {
        guard let worldTracker else {
            let arkitSession = ARKitSession()
            let worldTracker = WorldTrackingProvider()
            Task {try! await arkitSession.run([worldTracker])}
            self.arkitSession = arkitSession
            self.worldTracker = worldTracker
            return
        }
        guard let deviceAnchor = worldTracker.queryDeviceAnchor(atTimestamp: CACurrentMediaTime() + 0.01) else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer {commandBuffer.commit()}

        let cameraTransformAndProjections = DeviceDependants.cameraTransformAndProjections(deviceAnchor: deviceAnchor)

        scenePass.encode(in: commandBuffer, cameraTransformAndProjections: cameraTransformAndProjections, entity: entity)
        brightPass.encode(in: commandBuffer, inTexture: scenePass.outTexture)
        let bloomOut = bloomPass.encode(in: commandBuffer, inTexture: brightPass.outTexture)
        compositePass.encode(in: commandBuffer, inTextures: [scenePass.outTexture, bloomOut])

        if let blit = commandBuffer.makeBlitCommandEncoder() {
            defer {blit.endEncoding()}
            var uniforms = Uniforms(
                cameraTransformL: cameraTransformAndProjections.first!.transform,
                cameraTransformR: cameraTransformAndProjections.last!.transform,
                projection0: cameraTransformAndProjections.first!.projection,
                projection1: cameraTransformAndProjections.last!.projection,
                projection0Inverse: cameraTransformAndProjections.first!.projection.inverse,
                projection1Inverse: cameraTransformAndProjections.last!.projection.inverse,
            )
            withUnsafeBytes(of: &uniforms) { u in
                uniformsBuffer.contents().copyMemory(from: u.baseAddress!, byteCount: MemoryLayout<Uniforms>.size)
            }
            blit.copy(from: uniformsBuffer, sourceOffset: 0, sourceBytesPerRow: MemoryLayout<simd_float4x4>.size, sourceBytesPerImage: uniformsBuffer.length, sourceSize: MTLSize(width: 4, height: 5, depth: 1), to: uniformsMetalTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .init())
        }

        // copyPass.encode requires shaderRead, but blit does not require it
        func blitToDebugTexture(from: any MTLTexture) {
            if let blit = commandBuffer.makeBlitCommandEncoder() {
                defer {blit.endEncoding()}
                blit.copy(from: from, to: debugMetalTexture)
            }
        }
        switch debugBlit {
        case .none: break
        case .scene?: blitToDebugTexture(from: scenePass.outTexture)
        case .depth?: depthToColorPass.encode(in: commandBuffer, inTexture: scenePass.depthTexture)
        case .bright?: copyPass.encode(in: commandBuffer, inTexture: brightPass.outTexture)
        case .bloom?: copyPass.encode(in: commandBuffer, inTexture: bloomOut)
        case .composite?: blitToDebugTexture(from: compositePass.outTexture)
        }
    }
}

import simd
import ARKit

public enum DeviceDependants {
    // see also: https://stackoverflow.com/questions/78664948/exactly-where-is-worldtrackingprovider-querydeviceanchor-attached-in-visionos
    struct DeviceAnchorCameraTransformShift {
        var left: SIMD3<Float>
        var right: SIMD3<Float>
        init(ipd: Float, shiftY: Float, shiftZ: Float) {
            left = .init(-ipd / 2, shiftY, shiftZ)
            right =  .init(ipd / 2, shiftY, shiftZ)
        }
        nonisolated(unsafe) static var mono: Self = .init(ipd: 0, shiftY: 0, shiftZ: 0)
        // ipd: it maybe be distance between hardware cameras
        // sfhitY, shiftZ: derived from my experimentations. should be refined.
        nonisolated(unsafe) static var stereo: Self = .init(ipd: 0.064, shiftY: -0.0261, shiftZ: -0.0212)
    }
#if targetEnvironment(simulator)
    public static let viewCount: Int = 1
    static let projection = simd_float4x4([
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.7777778, 0.0, 0.0],
        [0.0, 0.0, 0.0, -1.0],
        [0.0, 0.0, 0.1, 0.0],
    ])
    static var aspectRatio: Float {projection[1][1] / projection[0][0]}
#else
    public static let viewCount: Int = 2
    static let cameraShift: DeviceAnchorCameraTransformShift = .stereo
    // using hard coded value, because we cannot get at runtime, as the only way to get them is from CompsitorLayer Drawable that cannot run simultaneously with ImmersiveView with RealityView.
    static let projection0 = simd_float4x4([
        [0.70956117, 2.7048769e-05, 0.0, 0.00025395412],
        [1.6707818e-06, 0.8844015, 0.0, 6.786168e-06],
        [-0.26731065, -0.08808379, 0.0, -1.0000936],
        [0.0, 0.0, 0.09691928, 0.0],
    ])
    static let projection1 = simd_float4x4([
        [0.70965976, -1.7333849e-05, 0.0, -0.00025292352],
        [2.0678665e-06, 0.8845193, 0.0, -8.016048e-06],
        [0.2677407, -0.086908735, 0.0, -1.0000918],
        [0.0, 0.0, 0.09693231, 0.0],
    ])
    static var aspectRatio: Float {projection0[1][1] / projection0[0][0]}
#endif
}
extension DeviceDependants {
    static func cameraTransformAndProjections(deviceAnchor: DeviceAnchor) -> [(transform: simd_float4x4, projection: simd_float4x4)] {
        let cameraTransform = deviceAnchor.originFromAnchorTransform
#if targetEnvironment(simulator)
        return [(cameraTransform, projection)]
#else
        let cameraRight4 = normalize(SIMD4<Float>(cameraTransform.columns.0.x,
                                                  cameraTransform.columns.0.y,
                                                  cameraTransform.columns.0.z,
                                                  0))
        let cameraUp4 = normalize(SIMD4<Float>(cameraTransform.columns.1.x,
                                               cameraTransform.columns.1.y,
                                               cameraTransform.columns.1.z,
                                               0))
        let cameraForward4 = normalize(SIMD4<Float>(cameraTransform.columns.2.x,
                                                    cameraTransform.columns.2.y,
                                                    cameraTransform.columns.2.z,
                                                    0))
        var cameraTransformL = cameraTransform
        var cameraTransformR = cameraTransform
        let shiftForL = cameraShift.left
        let shiftForR = cameraShift.right
        cameraTransformL.columns.3 += cameraRight4 * shiftForL.x + cameraUp4 * shiftForL.y + cameraForward4 * shiftForL.z
        cameraTransformR.columns.3 += cameraRight4 * shiftForR.x + cameraUp4 * shiftForR.y + cameraForward4 * shiftForR.z
        return [(cameraTransformL, projection0),
                (cameraTransformR, projection1)]
#endif
    }
}

#import <simd/simd.h>

/// MetalMap->Texture(blit)->RealityKit shader
struct Uniforms {
    simd_float4x4 cameraTransformL;
    simd_float4x4 cameraTransformR;
    simd_float4x4 projection0;
    simd_float4x4 projection1;
    simd_float4x4 projection0Inverse;
    simd_float4x4 projection1Inverse;
};
/// MetalMap->(vertex buffer)->vertex shader, as array, indexed by instance id for left/right eye
struct VertexUniforms {
    simd_float4x4 modelTransform;
    simd_float4x4 cameraTransform;
    simd_float4x4 cameraTransformInverse;
    simd_float4x4 projection;
    simd_float4x4 projectionInverse;
};
/// MetalMap->(fragment buffer)->fragment shader
struct FragmentUniforms {
    simd_int2 textureSize;
};

struct Vertex {
    simd_float3 position;
    simd_float2 uv; // optional?
    simd_float3 normal; // optional?
    simd_float3 tangent; // optional?
    simd_float3 bitangent; // optional?
};

import Foundation
import RealityKit
import Metal

public struct USDZLowLevelMeshImporter {
    public var mesh: LowLevelMesh
    public var materials: [any RealityKit.Material]

    @MainActor func modelEntity() throws -> ModelEntity {
        ModelEntity(mesh: try MeshResource(from: mesh), materials: materials)
    }

    @MainActor public init(usdz: ModelEntity, descriptor: LowLevelMesh.Descriptor = Vertex.descriptor) throws {
        let model = usdz.model!
        let usdzParts = model.mesh.contents.models.flatMap {$0.parts}
        let usdzLLMesh = try LowLevelMesh(descriptor: descriptor)
        self.mesh = usdzLLMesh
        self.materials = model.materials

        var totalVertexCount = 0
        var totalIndexCount = 0
        for part in usdzParts {
            guard let triangleIndices = part.triangleIndices else { return }
            let indexOffset = totalIndexCount
            let indexCount = triangleIndices.count
            defer {totalIndexCount += indexCount}
            let llPart = LowLevelMesh.Part(indexOffset: indexOffset, indexCount: indexCount, topology: .triangle, materialIndex: 0, bounds: .empty)
            usdzLLMesh.parts.append(llPart)

            NSLog("%@", "appending \(part.positions.elements.count) vertices at \(totalVertexCount), \(indexCount) indices at \(indexOffset)")

            usdzLLMesh.withUnsafeMutableBytes(bufferIndex: 0) {
                let positions = part.positions.elements
                let uvs = part.textureCoordinates?.elements
                let normals = part.normals?.elements
                let tangents = part.tangents?.elements
                let bitangents = part.bitangents?.elements
                if uvs != nil { NSLog("%@", "uv found on part") }
                if normals != nil { NSLog("%@", "normals found on part") }
                if tangents != nil { NSLog("%@", "tangents found on part") }
                if bitangents != nil { NSLog("%@", "bitangents found on part") }
                guard uvs == nil || uvs?.count == positions.count else { fatalError() }
                guard normals == nil || normals?.count == positions.count else { fatalError() }
                guard tangents == nil || tangents?.count == positions.count else { fatalError() }
                guard bitangents == nil || bitangents?.count == positions.count else { fatalError() }
                defer {totalVertexCount += positions.count}

                let p = $0.bindMemory(to: Vertex.self)
                positions.enumerated().forEach { i, xyz in
                    p[totalVertexCount + i] = Vertex(position: xyz, uv: uvs?[i], normal: normals?[i], tangent: tangents?[i], bitangent: bitangents?[i])
                }
            }
            usdzLLMesh.withUnsafeMutableIndices {
                let p = $0.bindMemory(to: UInt32.self)
                triangleIndices.enumerated().forEach {
                    p[indexOffset + $0.offset] = $0.element
                }
            }
        }
    }

    public struct Vertex {
        public var position: SIMD3<Float>
        public var uv: SIMD2<Float>?
        public var normal: SIMD3<Float>?
        public var tangent: SIMD3<Float>?
        public var bitangent: SIMD3<Float>?

        public static let vertexAttributes: [LowLevelMesh.Attribute] = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<Self>.offset(of: \.position)!),
            .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Self>.offset(of: \.uv)!),
            .init(semantic: .normal, format: .float3, offset: MemoryLayout<Self>.offset(of: \.normal)!),
            .init(semantic: .tangent, format: .float3, offset: MemoryLayout<Self>.offset(of: \.tangent)!),
            .init(semantic: .bitangent, format: .float3, offset: MemoryLayout<Self>.offset(of: \.bitangent)!),
        ]
        public static let vertexLayouts: [LowLevelMesh.Layout] = [
            .init(bufferIndex: 0, bufferStride: MemoryLayout<Self>.stride)
        ]
        public static var descriptor: LowLevelMesh.Descriptor {
            var desc = LowLevelMesh.Descriptor()
            desc.vertexAttributes = Vertex.vertexAttributes
            desc.vertexLayouts = Vertex.vertexLayouts
            desc.indexType = .uint32
            desc.vertexCapacity = 100_000
            desc.indexCapacity = 1_000_000
            return desc
        }
    }
}

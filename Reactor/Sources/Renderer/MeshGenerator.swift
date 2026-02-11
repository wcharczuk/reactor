import Foundation
import Metal
import simd

/// Generates procedural mesh data for the CRT monitor model
class MeshGenerator {

    struct MeshData {
        let vertexBuffer: MTLBuffer
        let indexBuffer: MTLBuffer
        let indexCount: Int
        let primitiveType: MTLPrimitiveType
    }

    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var texCoord: SIMD2<Float>
    }

    /// Generate the monitor body mesh — just a flat bezel frame around the screen.
    /// The monitor is centered at origin, screen facing +Z.
    static func generateMonitorBody(device: MTLDevice) -> MeshData {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []

        let w: Float = 0.80   // half-width (outer edge)
        let h: Float = 0.65   // half-height (outer edge)
        let bezel: Float = 0.04 // bezel width around screen

        // Screen cutout inner edge
        let sw = w - bezel
        let sh = h - bezel

        let fz: Float = 0.0 // front Z

        // Top bezel strip
        addQuad(&vertices, &indices,
                SIMD3<Float>(-w, h, fz), SIMD3<Float>(w, h, fz),
                SIMD3<Float>(w, sh, fz), SIMD3<Float>(-w, sh, fz),
                normal: SIMD3<Float>(0, 0, 1), uvMode: .stretch)

        // Bottom bezel strip
        addQuad(&vertices, &indices,
                SIMD3<Float>(-w, -sh, fz), SIMD3<Float>(w, -sh, fz),
                SIMD3<Float>(w, -h, fz), SIMD3<Float>(-w, -h, fz),
                normal: SIMD3<Float>(0, 0, 1), uvMode: .stretch)

        // Left bezel strip
        addQuad(&vertices, &indices,
                SIMD3<Float>(-w, sh, fz), SIMD3<Float>(-sw, sh, fz),
                SIMD3<Float>(-sw, -sh, fz), SIMD3<Float>(-w, -sh, fz),
                normal: SIMD3<Float>(0, 0, 1), uvMode: .stretch)

        // Right bezel strip
        addQuad(&vertices, &indices,
                SIMD3<Float>(sw, sh, fz), SIMD3<Float>(w, sh, fz),
                SIMD3<Float>(w, -sh, fz), SIMD3<Float>(sw, -sh, fz),
                normal: SIMD3<Float>(0, 0, 1), uvMode: .stretch)

        return createMeshData(device: device, vertices: vertices, indices: indices)
    }

    /// Generate the screen face quad (slightly recessed behind bezel)
    /// UV coordinates map the entire CRT texture to this quad
    static func generateScreenQuad(device: MTLDevice) -> MeshData {
        let bezel: Float = 0.04
        let w: Float = 0.80 - bezel
        let h: Float = 0.65 - bezel
        let z: Float = -0.002 // slightly recessed behind bezel

        var vertices: [Vertex] = []
        var indices: [UInt32] = []

        addQuad(&vertices, &indices,
                SIMD3<Float>(-w, h, z), SIMD3<Float>(w, h, z),
                SIMD3<Float>(w, -h, z), SIMD3<Float>(-w, -h, z),
                normal: SIMD3<Float>(0, 0, 1), uvMode: .screen)

        return createMeshData(device: device, vertices: vertices, indices: indices)
    }

    // MARK: - Helpers

    enum UVMode {
        case stretch  // UV 0-1 across the quad
        case screen   // UV for screen mapping (0,0 top-left to 1,1 bottom-right)
    }

    private static func addQuad(_ vertices: inout [Vertex], _ indices: inout [UInt32],
                                 _ tl: SIMD3<Float>, _ tr: SIMD3<Float>,
                                 _ br: SIMD3<Float>, _ bl: SIMD3<Float>,
                                 normal: SIMD3<Float>, uvMode: UVMode) {
        let baseIndex = UInt32(vertices.count)

        let uvTL: SIMD2<Float>
        let uvTR: SIMD2<Float>
        let uvBR: SIMD2<Float>
        let uvBL: SIMD2<Float>

        switch uvMode {
        case .stretch:
            uvTL = SIMD2<Float>(0, 0)
            uvTR = SIMD2<Float>(1, 0)
            uvBR = SIMD2<Float>(1, 1)
            uvBL = SIMD2<Float>(0, 1)
        case .screen:
            uvTL = SIMD2<Float>(0, 0)
            uvTR = SIMD2<Float>(1, 0)
            uvBR = SIMD2<Float>(1, 1)
            uvBL = SIMD2<Float>(0, 1)
        }

        vertices.append(Vertex(position: tl, normal: normal, texCoord: uvTL))
        vertices.append(Vertex(position: tr, normal: normal, texCoord: uvTR))
        vertices.append(Vertex(position: br, normal: normal, texCoord: uvBR))
        vertices.append(Vertex(position: bl, normal: normal, texCoord: uvBL))

        // Two triangles
        indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
        indices.append(contentsOf: [baseIndex, baseIndex + 2, baseIndex + 3])
    }

    private static func addBox(_ vertices: inout [Vertex], _ indices: inout [UInt32],
                                center: SIMD3<Float>, size: SIMD3<Float>) {
        let hw = size.x / 2
        let hh = size.y / 2
        let hd = size.z / 2
        let c = center

        // Front
        addQuad(&vertices, &indices,
                c + SIMD3<Float>(-hw, hh, hd), c + SIMD3<Float>(hw, hh, hd),
                c + SIMD3<Float>(hw, -hh, hd), c + SIMD3<Float>(-hw, -hh, hd),
                normal: SIMD3<Float>(0, 0, 1), uvMode: .stretch)
        // Back
        addQuad(&vertices, &indices,
                c + SIMD3<Float>(hw, hh, -hd), c + SIMD3<Float>(-hw, hh, -hd),
                c + SIMD3<Float>(-hw, -hh, -hd), c + SIMD3<Float>(hw, -hh, -hd),
                normal: SIMD3<Float>(0, 0, -1), uvMode: .stretch)
        // Top
        addQuad(&vertices, &indices,
                c + SIMD3<Float>(-hw, hh, -hd), c + SIMD3<Float>(hw, hh, -hd),
                c + SIMD3<Float>(hw, hh, hd), c + SIMD3<Float>(-hw, hh, hd),
                normal: SIMD3<Float>(0, 1, 0), uvMode: .stretch)
        // Bottom
        addQuad(&vertices, &indices,
                c + SIMD3<Float>(-hw, -hh, hd), c + SIMD3<Float>(hw, -hh, hd),
                c + SIMD3<Float>(hw, -hh, -hd), c + SIMD3<Float>(-hw, -hh, -hd),
                normal: SIMD3<Float>(0, -1, 0), uvMode: .stretch)
        // Left
        addQuad(&vertices, &indices,
                c + SIMD3<Float>(-hw, hh, -hd), c + SIMD3<Float>(-hw, hh, hd),
                c + SIMD3<Float>(-hw, -hh, hd), c + SIMD3<Float>(-hw, -hh, -hd),
                normal: SIMD3<Float>(-1, 0, 0), uvMode: .stretch)
        // Right
        addQuad(&vertices, &indices,
                c + SIMD3<Float>(hw, hh, hd), c + SIMD3<Float>(hw, hh, -hd),
                c + SIMD3<Float>(hw, -hh, -hd), c + SIMD3<Float>(hw, -hh, hd),
                normal: SIMD3<Float>(1, 0, 0), uvMode: .stretch)
    }

    private static func createMeshData(device: MTLDevice, vertices: [Vertex], indices: [UInt32]) -> MeshData {
        let vertexBuffer = device.makeBuffer(bytes: vertices,
                                              length: MemoryLayout<Vertex>.stride * vertices.count,
                                              options: .storageModeShared)!
        let indexBuffer = device.makeBuffer(bytes: indices,
                                             length: MemoryLayout<UInt32>.stride * indices.count,
                                             options: .storageModeShared)!
        return MeshData(vertexBuffer: vertexBuffer,
                        indexBuffer: indexBuffer,
                        indexCount: indices.count,
                        primitiveType: .triangle)
    }
}

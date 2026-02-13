import Foundation
import Metal
import MetalKit
import simd

/// Renders the 3D CRT monitor scene
class SceneRenderer {
    private let device: MTLDevice
    private var monitorBodyMesh: MeshGenerator.MeshData!
    private var screenQuadMesh: MeshGenerator.MeshData!

    // Pipeline states
    private var monitorPipelineState: MTLRenderPipelineState!
    private var screenPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var samplerState: MTLSamplerState!

    // Scene uniforms
    private var sceneUniforms = SceneUniformsSwift()
    private var monitorMaterial = MaterialUniformsSwift()

    // Camera — close enough to fill the window with the screen + border
    private let cameraPosition = SIMD3<Float>(0.0, 0.0, 1.9)
    private let cameraTarget = SIMD3<Float>(0.0, 0.0, 0.0)
    private let cameraUp = SIMD3<Float>(0.0, 1.0, 0.0)

    // Light
    private let lightPosition = SIMD3<Float>(2.0, 3.0, 4.0)

    init(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        self.device = device
        setupMeshes()
        setupPipelines(library: library, pixelFormat: pixelFormat)
        setupMaterial()
        setupSampler()
    }

    private func setupMeshes() {
        monitorBodyMesh = MeshGenerator.generateMonitorBody(device: device)
        screenQuadMesh = MeshGenerator.generateScreenQuad(device: device)
    }

    private func setupPipelines(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        // Monitor body pipeline
        let monitorVertexFunc = library.makeFunction(name: "scene_vertex")!
        let monitorFragmentFunc = library.makeFunction(name: "scene_fragment")!

        let monitorDesc = MTLRenderPipelineDescriptor()
        monitorDesc.vertexFunction = monitorVertexFunc
        monitorDesc.fragmentFunction = monitorFragmentFunc
        monitorDesc.colorAttachments[0].pixelFormat = pixelFormat
        monitorDesc.depthAttachmentPixelFormat = .depth32Float

        monitorPipelineState = try! device.makeRenderPipelineState(descriptor: monitorDesc)

        // Screen face pipeline
        let screenFragmentFunc = library.makeFunction(name: "screen_fragment")!

        let screenDesc = MTLRenderPipelineDescriptor()
        screenDesc.vertexFunction = monitorVertexFunc
        screenDesc.fragmentFunction = screenFragmentFunc
        screenDesc.colorAttachments[0].pixelFormat = pixelFormat
        screenDesc.depthAttachmentPixelFormat = .depth32Float

        screenPipelineState = try! device.makeRenderPipelineState(descriptor: screenDesc)

        // Depth stencil
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)
    }

    private func setupMaterial() {
        // Dark beige/grey monitor frame
        monitorMaterial.baseColor = SIMD3<Float>(0.45, 0.42, 0.38)
        monitorMaterial.roughness = 0.7
        monitorMaterial.metallic = 0.0
    }

    private func setupSampler() {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .notMipmapped
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: desc)
    }

    func render(encoder: MTLRenderCommandEncoder, crtTexture: MTLTexture, viewportSize: CGSize) {
        updateUniforms(viewportSize: viewportSize)

        encoder.setDepthStencilState(depthStencilState)

        // 1. Render monitor body
        encoder.setRenderPipelineState(monitorPipelineState)
        encoder.setVertexBuffer(monitorBodyMesh.vertexBuffer, offset: 0, index: 0)

        var uniforms = sceneUniforms.metalStruct
        encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 0)

        var material = monitorMaterial.metalStruct
        encoder.setFragmentBytes(&material, length: MemoryLayout.stride(ofValue: material), index: 1)

        encoder.drawIndexedPrimitives(type: monitorBodyMesh.primitiveType,
                                       indexCount: monitorBodyMesh.indexCount,
                                       indexType: .uint32,
                                       indexBuffer: monitorBodyMesh.indexBuffer,
                                       indexBufferOffset: 0)

        // 2. Render screen face with CRT texture
        encoder.setRenderPipelineState(screenPipelineState)
        encoder.setVertexBuffer(screenQuadMesh.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 0)
        encoder.setFragmentTexture(crtTexture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)

        encoder.drawIndexedPrimitives(type: screenQuadMesh.primitiveType,
                                       indexCount: screenQuadMesh.indexCount,
                                       indexType: .uint32,
                                       indexBuffer: screenQuadMesh.indexBuffer,
                                       indexBufferOffset: 0)
    }

    private func updateUniforms(viewportSize: CGSize) {
        let aspect = Float(viewportSize.width / viewportSize.height)

        // Model matrix (identity - monitor at origin)
        sceneUniforms.modelMatrix = matrix_identity_float4x4

        // View matrix
        sceneUniforms.viewMatrix = lookAt(eye: cameraPosition, target: cameraTarget, up: cameraUp)

        // Projection matrix
        sceneUniforms.projectionMatrix = perspective(fovY: Float.pi / 4.7, aspect: aspect,
                                                      nearZ: 0.1, farZ: 100.0)

        // Normal matrix (inverse transpose of model)
        sceneUniforms.normalMatrix = matrix_identity_float4x4

        sceneUniforms.lightPosition = lightPosition
        sceneUniforms.ambientIntensity = 0.15
        sceneUniforms.lightColor = SIMD3<Float>(1.0, 0.95, 0.9)
        sceneUniforms.diffuseIntensity = 0.7
        sceneUniforms.cameraPosition = cameraPosition
        sceneUniforms.specularIntensity = 0.3
        sceneUniforms.specularPower = 32.0
    }

    // MARK: - Math Helpers

    private func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let z = normalize(eye - target)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        return float4x4(columns: (
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        ))
    }

    private func perspective(fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> float4x4 {
        let yScale = 1.0 / tan(fovY * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ

        return float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, -(farZ + nearZ) / zRange, -1),
            SIMD4<Float>(0, 0, -2 * farZ * nearZ / zRange, 0)
        ))
    }
}

// MARK: - Swift-side uniform structs (mirrors ShaderTypes.h)

struct SceneUniformsSwift {
    var modelMatrix: float4x4 = matrix_identity_float4x4
    var viewMatrix: float4x4 = matrix_identity_float4x4
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    var normalMatrix: float4x4 = matrix_identity_float4x4
    var lightPosition: SIMD3<Float> = .zero
    var ambientIntensity: Float = 0.1
    var lightColor: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    var diffuseIntensity: Float = 0.8
    var cameraPosition: SIMD3<Float> = .zero
    var specularIntensity: Float = 0.3
    var specularPower: Float = 32.0
    var padding1: Float = 0
    var padding2: Float = 0
    var padding3: Float = 0

    var metalStruct: SceneUniformsSwift { self }
}

struct MaterialUniformsSwift {
    var baseColor: SIMD3<Float> = SIMD3<Float>(0.8, 0.8, 0.8)
    var roughness: Float = 0.5
    var metallic: Float = 0.0
    var padding1: Float = 0
    var padding2: Float = 0
    var padding3: Float = 0

    var metalStruct: MaterialUniformsSwift { self }
}

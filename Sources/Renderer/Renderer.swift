import Foundation
import Metal
import MetalKit
import simd

/// Main renderer that orchestrates the 2-pass pipeline:
/// 1. Terminal buffer → texture (via CoreGraphics)
/// 2. CRT post-processing shader → screen
class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    // Sub-renderers
    private var terminalRenderer: TerminalRenderer!

    // CRT post-processing
    private var crtPipelineState: MTLRenderPipelineState!
    private var crtSamplerState: MTLSamplerState!
    private var quadVertexBuffer: MTLBuffer!

    // CRT uniforms
    private var crtUniforms = CRTUniformsSwift()
    private var startTime: CFAbsoluteTime

    private var currentViewportSize: CGSize = .zero

    // Game references
    var terminalBuffer: TerminalBuffer!
    var gameLoop: GameLoop?
    var onFrame: (() -> Void)?

    init?(metalView: MTKView) {
        guard let device = metalView.device ?? MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device
        metalView.device = device

        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue
        self.startTime = CFAbsoluteTimeGetCurrent()

        super.init()

        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        metalView.preferredFramesPerSecond = 60
        metalView.framebufferOnly = false

        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create default Metal library")
            return nil
        }

        // Initialize sub-renderers
        terminalRenderer = TerminalRenderer(device: device)

        // Setup CRT pipeline
        setupCRTPipeline(library: library, pixelFormat: metalView.colorPixelFormat)
        setupQuadVertexBuffer()
        setupCRTSampler()
        setupCRTUniforms()
    }

    // MARK: - Setup

    private func setupCRTPipeline(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        let vertexFunc = library.makeFunction(name: "crt_vertex")!
        let fragmentFunc = library.makeFunction(name: "crt_fragment")!

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFunc
        desc.fragmentFunction = fragmentFunc
        desc.colorAttachments[0].pixelFormat = pixelFormat

        crtPipelineState = try! device.makeRenderPipelineState(descriptor: desc)
    }

    private static let quadPaddingPixels: Float = 48.0 // ~24pt on 2x retina

    private func setupQuadVertexBuffer() {
        // Initial buffer — rebuilt when viewport size is known
        updateQuadVertexBuffer(viewportSize: CGSize(width: 2880, height: 1800))
    }

    private func updateQuadVertexBuffer(viewportSize: CGSize) {
        let w = Float(viewportSize.width)
        let h = Float(viewportSize.height)
        guard w > 0, h > 0 else { return }

        let px = Self.quadPaddingPixels / w * 2.0
        let py = Self.quadPaddingPixels / h * 2.0

        let l: Float = -1.0 + px
        let r: Float =  1.0 - px
        let b: Float = -1.0 + py
        let t: Float =  1.0 - py

        let vertices: [Float] = [
            // position  texcoord
            l, b,   0.0, 1.0,
            r, b,   1.0, 1.0,
            l, t,   0.0, 0.0,

            l, t,   0.0, 0.0,
            r, b,   1.0, 1.0,
            r, t,   1.0, 0.0,
        ]
        quadVertexBuffer = device.makeBuffer(bytes: vertices,
                                              length: vertices.count * MemoryLayout<Float>.stride,
                                              options: .storageModeShared)
    }

    private func setupCRTSampler() {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .notMipmapped
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        crtSamplerState = device.makeSamplerState(descriptor: desc)
    }

    private func setupCRTUniforms() {
        crtUniforms.curvature = 0.0
        crtUniforms.scanlineIntensity = 0.06
        crtUniforms.scanlineCount = Float(TerminalRenderer.textureHeight) / 2.0
        crtUniforms.glowIntensity = 0.25
        crtUniforms.vignetteStrength = 0.12
        crtUniforms.flickerAmount = 0.15
        crtUniforms.brightness = 1.5
        crtUniforms.resolution = SIMD2<Float>(Float(TerminalRenderer.textureWidth),
                                               Float(TerminalRenderer.textureHeight))
        crtUniforms.greenTintR = 0.08
        crtUniforms.greenTintG = 1.0
        crtUniforms.greenTintB = 0.08
        crtUniforms.phosphorPersistence = 0.85
        crtUniforms.noiseAmount = 0.1
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentViewportSize = size
        updateQuadVertexBuffer(viewportSize: size)
    }

    func draw(in view: MTKView) {
        // Update game state
        let dt = 1.0 / Double(view.preferredFramesPerSecond)
        gameLoop?.update(dt: dt)

        // Re-render terminal buffer with latest state
        onFrame?()

        // Update time uniform
        crtUniforms.time = Float(CFAbsoluteTimeGetCurrent() - startTime)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        // Pass 1: Render terminal buffer to texture
        if let buffer = terminalBuffer {
            terminalRenderer.render(buffer: buffer)
        }

        // Pass 2: CRT post-processing directly to screen
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        encoder.setRenderPipelineState(crtPipelineState)
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)

        var uniforms = crtUniforms
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CRTUniformsSwift>.stride, index: 0)
        encoder.setFragmentTexture(terminalRenderer.texture, index: 0)
        encoder.setFragmentSamplerState(crtSamplerState, index: 0)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Capture the terminal texture as PNG data (pre-CRT).
    func captureTerminalPNG() -> Data? {
        return terminalRenderer.capturePNG()
    }
}

// MARK: - CRT Uniforms (Swift side)

struct CRTUniformsSwift {
    var time: Float = 0
    var curvature: Float = 0.02
    var scanlineIntensity: Float = 0.15
    var scanlineCount: Float = 768
    var glowIntensity: Float = 0.4
    var vignetteStrength: Float = 0.3
    var flickerAmount: Float = 0.3
    var brightness: Float = 1.3
    var resolution: SIMD2<Float> = SIMD2<Float>(2560, 1536)
    var greenTintR: Float = 0.08
    var greenTintG: Float = 1.0
    var greenTintB: Float = 0.08
    var phosphorPersistence: Float = 0.85
    var noiseAmount: Float = 0.3
    var padding: Float = 0
}

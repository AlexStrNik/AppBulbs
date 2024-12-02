//
//  DecorationRenderer.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import MetalKit

let rectangleVertices: [Float] = [
    0, 0,
    1, 0,
    1, 1,
    0, 1,
]
let rectangleIndices: [ushort] = [
    0, 1, 2,
    0, 2, 3
]

struct WindowUniforms {
    var position: SIMD2<Float>
    var size: SIMD2<Float>
}

struct GlobalUniforms {
    var screenSize: SIMD2<Float>
    var size: SIMD2<Float>
}

struct RenderUniforms {
    var time: Float
    var bulbScale: Float
}

func makeDecorationPipelineState(
    device: MTLDevice,
    vertexFunction: MTLFunction,
    fragmentFunction: MTLFunction
) -> MTLRenderPipelineState {
    let decorationPipelineStateDescriptor = MTLRenderPipelineDescriptor()
    decorationPipelineStateDescriptor.vertexFunction = vertexFunction
    decorationPipelineStateDescriptor.fragmentFunction = fragmentFunction
    decorationPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    decorationPipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
    decorationPipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
    decorationPipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
    decorationPipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    decorationPipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    decorationPipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    decorationPipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    
    do {
        return try device.makeRenderPipelineState(descriptor: decorationPipelineStateDescriptor)
    } catch {
        fatalError("Failed to create render pipeline state")
    }
}

func makeClearPipelineState(
    device: MTLDevice,
    vertexFunction: MTLFunction,
    fragmentFunction: MTLFunction
) -> MTLRenderPipelineState {
    let clearPipelineState = MTLRenderPipelineDescriptor()
    clearPipelineState.vertexFunction = vertexFunction
    clearPipelineState.fragmentFunction = fragmentFunction
    clearPipelineState.colorAttachments[0].pixelFormat = .bgra8Unorm
    clearPipelineState.colorAttachments[0].isBlendingEnabled = true
    clearPipelineState.colorAttachments[0].rgbBlendOperation = .subtract
    clearPipelineState.colorAttachments[0].alphaBlendOperation = .subtract
    clearPipelineState.colorAttachments[0].sourceRGBBlendFactor = .zero
    clearPipelineState.colorAttachments[0].sourceAlphaBlendFactor = .zero
    clearPipelineState.colorAttachments[0].destinationRGBBlendFactor = .oneMinusDestinationAlpha
    clearPipelineState.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusDestinationAlpha
    
    do {
        return try device.makeRenderPipelineState(descriptor: clearPipelineState)
    } catch {
        fatalError("Failed to create render pipeline state")
    }
}

class DecorationRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let vertexFunction: MTLFunction
    private let decorationFragmentFunction: MTLFunction
    private let clearFragmentFunction: MTLFunction
    
    private let decorationPipelineState: MTLRenderPipelineState
    private let clearPipelineState: MTLRenderPipelineState
    
    private let rectangleVertexBuffer: MTLBuffer
    private let rectangleIndexBuffer: MTLBuffer
    
    private var currentTime: Float = 0
    
    var globalUniforms: GlobalUniforms = GlobalUniforms(
        screenSize: .zero,
        size: .zero
    )
    
    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        let library = self.device.makeDefaultLibrary()!
        
        self.vertexFunction = library.makeFunction(name: "vertexFunction")!
        self.decorationFragmentFunction = library.makeFunction(name: "decorationFragmentFunction")!
        self.clearFragmentFunction = library.makeFunction(name: "clearFragmentFunction")!
        
        self.rectangleVertexBuffer = device.makeBuffer(
            bytes: rectangleVertices,
            length: rectangleVertices.count * MemoryLayout<Float>.stride,
            options: MTLResourceOptions.storageModeShared
        )!
        self.rectangleIndexBuffer = device.makeBuffer(
            bytes: rectangleIndices,
            length: rectangleIndices.count * MemoryLayout<ushort>.stride,
            options: MTLResourceOptions.storageModeShared
        )!
        
        self.decorationPipelineState = makeDecorationPipelineState(
            device: device, vertexFunction: vertexFunction, fragmentFunction: decorationFragmentFunction
        )
        self.clearPipelineState = makeClearPipelineState(
            device: device, vertexFunction: vertexFunction, fragmentFunction: clearFragmentFunction
        )
        
        super.init()
    }

    func draw(in view: MTKView) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        alignDecorations()
        
        currentTime += 1.0 / Float(view.preferredFramesPerSecond)
        
        let windows = AppDelegate.windowDecorations.values.filter { $0.order >= 0 }.sorted { $0.order > $1.order }
        for window in windows {
            var windowUniforms = WindowUniforms(
                position: window.position,
                size: window.size
            )
            
            drawDecoration(
                commandEncoder: renderEncoder,
                windowUniforms: &windowUniforms
            )
        }
                
        renderEncoder.endEncoding()

        let drawable = view.currentDrawable!
        commandBuffer.present(drawable)
            
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let screenSize = NSScreen.main!.frame
        
        self.globalUniforms = GlobalUniforms(
            screenSize: simd_float2(Float(screenSize.width), Float(screenSize.height)),
            size: simd_float2(Float(size.width), Float(size.height))
        )
    }
    
    func drawDecoration(commandEncoder: MTLRenderCommandEncoder, windowUniforms: inout WindowUniforms) {
        commandEncoder.setRenderPipelineState(clearPipelineState)
        commandEncoder.setVertexBuffer(rectangleVertexBuffer, offset: 0, index: 0)
        
        commandEncoder.setVertexBytes(&globalUniforms, length: MemoryLayout<GlobalUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&windowUniforms, length: MemoryLayout<WindowUniforms>.stride, index: 2)
        
        commandEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: rectangleIndexBuffer,
            indexBufferOffset: 0
        )
        
        commandEncoder.setRenderPipelineState(decorationPipelineState)
        commandEncoder.setVertexBuffer(rectangleVertexBuffer, offset: 0, index: 0)
        
        commandEncoder.setVertexBytes(&globalUniforms, length: MemoryLayout<GlobalUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&windowUniforms, length: MemoryLayout<WindowUniforms>.stride, index: 2)
        
        var renderUniforms = RenderUniforms(
            time: currentTime,
            bulbScale: 1.5
        )
        
        commandEncoder.setFragmentBytes(&renderUniforms, length: MemoryLayout<RenderUniforms>.stride, index: 1)
        
        commandEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: rectangleIndexBuffer,
            indexBufferOffset: 0
        )
    }
}

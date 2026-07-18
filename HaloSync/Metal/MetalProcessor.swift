// HaloSync — Metal/MetalProcessor.swift
// Swift wrapper around the Metal pipeline.
// Creates the MTLDevice, compiles the ZoneSampler compute pipeline,
// manages the output buffer, and converts GPU results to [LEDColor].
//
// Design: Stateless between frames — all state is in the pipeline and buffers.
// Thread safety: All Metal calls must happen on the MetalActor.

import Metal
import CoreVideo
import Foundation
import simd

// MARK: - MetalProcessorError

public enum MetalProcessorError: Error {
    case noMetalDevice
    case pipelineCreationFailed(Error)
    case textureCreationFailed
    case commandBufferFailed
}

// MARK: - ZoneSamplerParams (mirrors Metal struct)

struct ZoneSamplerParams {
    var ledCount:          UInt32
    var samplingDepth:     UInt32
    var samplesPerZone:    UInt32
    var blackBarThreshold: Float
    var gamma:             Float
    var saturationBoost:   Float
    var textureWidth:      UInt32
    var textureHeight:     UInt32
}

// MARK: - MetalProcessor

/// Manages the GPU compute pipeline for LED zone sampling.
/// One instance per active capture session.
public final class MetalProcessor: @unchecked Sendable {

    // MARK: - Metal State

    private let device:        MTLDevice
    private let commandQueue:  MTLCommandQueue
    private let pipeline:      MTLComputePipelineState
    private let textureCache:  CVMetalTextureCache

    // MARK: - Init

    public init() throws {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw MetalProcessorError.noMetalDevice
        }
        guard let queue = dev.makeCommandQueue() else {
            throw MetalProcessorError.noMetalDevice
        }
        guard let library = dev.makeDefaultLibrary(),
              let fn = library.makeFunction(name: "zoneSampler") else {
            throw MetalProcessorError.pipelineCreationFailed(
                NSError(domain: "MetalProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Shader function not found"])
            )
        }

        do {
            pipeline = try dev.makeComputePipelineState(function: fn)
        } catch {
            throw MetalProcessorError.pipelineCreationFailed(error)
        }

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, dev, nil, &cache)
        guard let resolvedCache = cache else {
            throw MetalProcessorError.noMetalDevice
        }

        self.device       = dev
        self.commandQueue = queue
        self.textureCache = resolvedCache

        HaloLogger.metal.info("MetalProcessor initialized on \(dev.name)")
    }

    // MARK: - Public API
    
    /// Creates a GPU buffer from normalized screen coordinates.
    public func makeLayoutBuffer(coordinates: [simd_float2]) -> MTLBuffer? {
        let size = coordinates.count * MemoryLayout<simd_float2>.stride
        return device.makeBuffer(bytes: coordinates, length: size, options: .storageModeShared)
    }

    /// Processes a captured pixel buffer through the GPU zone sampler.
    /// - Parameters:
    ///   - pixelBuffer: GPU-backed CVPixelBuffer from ScreenCaptureKit.
    ///   - settings:    Processing configuration.
    ///   - ledCount:    Total LEDs.
    ///   - layoutBuffer: Pre-compiled GPU buffer of float2 coordinates.
    /// - Returns: Array of per-LED colors.
    public func process(
        pixelBuffer:  CVPixelBuffer,
        settings:     ProcessingSettings,
        ledCount:     Int,
        layoutBuffer: MTLBuffer
    ) throws -> [LEDColor] {
        guard ledCount > 0 else { return [] }

        // 1. Create Metal texture from CVPixelBuffer (zero-copy via IOSurface).
        guard let texture = makeTexture(from: pixelBuffer) else {
            throw MetalProcessorError.textureCreationFailed
        }

        // 2. Allocate output buffer.
        let bufferSize = ledCount * MemoryLayout<Float>.size * 4 // float4 per LED
        guard let outputBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            throw MetalProcessorError.textureCreationFailed
        }

        // 3. Build params.
        var params = ZoneSamplerParams(
            ledCount:          UInt32(ledCount),
            samplingDepth:     UInt32(settings.samplingDepth),
            samplesPerZone:    UInt32(settings.samplesPerZone),
            blackBarThreshold: settings.blackBarDetection ? settings.blackBarThreshold : 0,
            gamma:             settings.gamma,
            saturationBoost:   settings.ambientStrength,
            textureWidth:      UInt32(texture.width),
            textureHeight:     UInt32(texture.height)
        )

        // 4. Encode and dispatch.
        guard let cmdBuffer   = commandQueue.makeCommandBuffer(),
              let cmdEncoder  = cmdBuffer.makeComputeCommandEncoder() else {
            throw MetalProcessorError.commandBufferFailed
        }

        cmdEncoder.setComputePipelineState(pipeline)
        cmdEncoder.setTexture(texture, index: 0)
        cmdEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        cmdEncoder.setBytes(&params, length: MemoryLayout<ZoneSamplerParams>.size, index: 1)
        cmdEncoder.setBuffer(layoutBuffer, offset: 0, index: 2)

        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, ledCount), height: 1, depth: 1)
        let threadgroups    = MTLSize(width: (ledCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        cmdEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)

        cmdEncoder.endEncoding()
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        // 5. Read output buffer.
        let ptr = outputBuffer.contents().bindMemory(to: Float.self, capacity: ledCount * 4)
        var colors = [LEDColor]()
        colors.reserveCapacity(ledCount)

        for i in 0..<ledCount {
            let base = i * 4
            colors.append(LEDColor(
                red:   ptr[base + 0],
                green: ptr[base + 1],
                blue:  ptr[base + 2]
            ))
        }

        return colors
    }

    // MARK: - Private

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            w, h,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess, let cvTex = cvTexture else { return nil }
        return CVMetalTextureGetTexture(cvTex)
    }
}

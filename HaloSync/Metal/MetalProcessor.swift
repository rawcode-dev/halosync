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
    var topCount:          UInt32
    var rightCount:        UInt32
    var bottomCount:       UInt32
    var leftCount:         UInt32
    var samplingDepth:     UInt32
    var samplesPerZone:    UInt32
    var blackBarThreshold: Float
    var gamma:             Float
    var textureWidth:      UInt32
    var textureHeight:     UInt32
}

// MARK: - LEDZoneLayout

/// Describes how LEDs are distributed across screen edges.
public struct LEDZoneLayout: Sendable {
    public var topCount:    Int
    public var rightCount:  Int
    public var bottomCount: Int
    public var leftCount:   Int

    public var totalCount: Int { topCount + rightCount + bottomCount + leftCount }

    /// Creates a symmetric layout given total LED count.
    /// Default: equal distribution across all 4 edges.
    public static func symmetric(total: Int) -> LEDZoneLayout {
        let side = total / 4
        let extra = total % 4
        return LEDZoneLayout(
            topCount:    side + (extra > 0 ? 1 : 0),
            rightCount:  side + (extra > 1 ? 1 : 0),
            bottomCount: side + (extra > 2 ? 1 : 0),
            leftCount:   side
        )
    }
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

    /// Processes a captured pixel buffer through the GPU zone sampler.
    /// - Parameters:
    ///   - pixelBuffer: GPU-backed CVPixelBuffer from ScreenCaptureKit.
    ///   - settings:    Processing configuration.
    ///   - layout:      LED zone distribution.
    /// - Returns: Array of per-LED colors.
    public func process(
        pixelBuffer: CVPixelBuffer,
        settings:    ProcessingSettings,
        layout:      LEDZoneLayout
    ) throws -> [LEDColor] {
        let ledCount = layout.totalCount
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
            topCount:          UInt32(layout.topCount),
            rightCount:        UInt32(layout.rightCount),
            bottomCount:       UInt32(layout.bottomCount),
            leftCount:         UInt32(layout.leftCount),
            samplingDepth:     UInt32(settings.samplingDepth),
            samplesPerZone:    UInt32(settings.samplesPerZone),
            blackBarThreshold: settings.blackBarDetection ? settings.blackBarThreshold : 0,
            gamma:             settings.gamma,
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

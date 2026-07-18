// HaloSync — Metal/Shaders/ZoneSampler.metal
// GPU compute shader that samples LED color zones from a captured display frame.
//
// Algorithm:
//   1. Each LED maps to a rectangular zone at the screen edge.
//   2. Within each zone, we take N sub-pixel samples.
//   3. Samples are weighted — pixels closer to the edge count more.
//   4. Black bar regions are suppressed if their luminance is below threshold.
//   5. Final weighted average is written to the output buffer.
//
// This runs entirely on the GPU — zero CPU involvement in the hot path.

#include <metal_stdlib>
using namespace metal;

// MARK: - Types

struct LEDColorOutput {
    float r;
    float g;
    float b;
    float _padding; // Align to 16 bytes.
};

struct ZoneSamplerParams {
    uint   ledCount;          // Total number of LEDs.
    uint   topCount;          // LEDs on top edge.
    uint   rightCount;        // LEDs on right edge.
    uint   bottomCount;       // LEDs on bottom edge.
    uint   leftCount;         // LEDs on left edge.
    uint   samplingDepth;     // Pixel rows to sample from edge.
    uint   samplesPerZone;    // Sample points per LED zone.
    float  blackBarThreshold; // Luminance below this = suppress.
    float  gamma;             // Display gamma for linearization.
    uint   textureWidth;
    uint   textureHeight;
};

// MARK: - Helpers

/// Convert sRGB gamma-encoded value to linear light.
inline float linearize(float v, float gamma) {
    return pow(max(v, 0.0f), gamma);
}

/// Compute luminance of a linear RGB color.
inline float luminance(float3 c) {
    return dot(c, float3(0.2126f, 0.7152f, 0.0722f));
}

// MARK: - Main Compute Kernel

kernel void zoneSampler(
    texture2d<float, access::sample>    inTexture   [[ texture(0) ]],
    device LEDColorOutput*              outBuffer   [[ buffer(0) ]],
    constant ZoneSamplerParams&         params      [[ buffer(1) ]],
    uint                                gid         [[ thread_position_in_grid ]]
) {
    if (gid >= params.ledCount) return;

    constexpr sampler s(filter::linear, address::clamp_to_edge);

    const float W = float(params.textureWidth);
    const float H = float(params.textureHeight);
    const uint depth = max(params.samplingDepth, 1u);

    float3 colorAccum = float3(0.0f);
    float  weightAccum = 0.0f;

    uint led = gid;

    // Determine which edge this LED belongs to.
    // Layout: top (L→R) → right (T→B) → bottom (R→L) → left (B→T).
    float2 zoneMin, zoneMax;

    if (led < params.topCount) {
        // Top edge
        float segW = W / float(params.topCount);
        float x0 = float(led) * segW;
        zoneMin = float2(x0,     0.0f);
        zoneMax = float2(x0 + segW, float(depth));
    } else if (led < params.topCount + params.rightCount) {
        // Right edge
        uint i = led - params.topCount;
        float segH = H / float(params.rightCount);
        float y0 = float(i) * segH;
        zoneMin = float2(W - float(depth), y0);
        zoneMax = float2(W,               y0 + segH);
    } else if (led < params.topCount + params.rightCount + params.bottomCount) {
        // Bottom edge (reversed: right to left)
        uint i = params.bottomCount - 1 - (led - params.topCount - params.rightCount);
        float segW = W / float(params.bottomCount);
        float x0 = float(i) * segW;
        zoneMin = float2(x0,     H - float(depth));
        zoneMax = float2(x0 + segW, H);
    } else {
        // Left edge (reversed: bottom to top)
        uint i = params.leftCount - 1 - (led - params.topCount - params.rightCount - params.bottomCount);
        float segH = H / float(params.leftCount);
        float y0 = float(i) * segH;
        zoneMin = float2(0.0f,       y0);
        zoneMax = float2(float(depth), y0 + segH);
    }

    // Sub-pixel sampling within the zone.
    const uint sqrtSamples = max(uint(sqrt(float(params.samplesPerZone))), 1u);
    const float2 zoneSize = zoneMax - zoneMin;

    for (uint sy = 0; sy < sqrtSamples; ++sy) {
        for (uint sx = 0; sx < sqrtSamples; ++sx) {
            float2 offset = float2(
                (float(sx) + 0.5f) / float(sqrtSamples),
                (float(sy) + 0.5f) / float(sqrtSamples)
            );
            float2 px = zoneMin + offset * zoneSize;
            float2 uv = px / float2(W, H);

            float4 sample = inTexture.sample(s, uv);
            float3 linear = float3(
                linearize(sample.r, params.gamma),
                linearize(sample.g, params.gamma),
                linearize(sample.b, params.gamma)
            );

            float lum = luminance(linear);
            float weight = (lum > params.blackBarThreshold) ? 1.0f : 0.0f;

            colorAccum  += linear * weight;
            weightAccum += weight;
        }
    }

    float3 finalColor = (weightAccum > 0.0f)
        ? colorAccum / weightAccum
        : float3(0.0f);

    outBuffer[gid].r = saturate(finalColor.r);
    outBuffer[gid].g = saturate(finalColor.g);
    outBuffer[gid].b = saturate(finalColor.b);
    outBuffer[gid]._padding = 0.0f;
}

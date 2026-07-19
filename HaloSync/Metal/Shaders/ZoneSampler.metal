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
    uint   samplingDepth;     // Pixel radius to sample.
    uint   samplesPerZone;    // Sample points per LED zone.
    float  blackBarThreshold; // Luminance below this = suppress.
    float  gamma;             // Display gamma for linearization.
    float  saturationBoost;   // Boost color vibrancy
    uint   textureWidth;
    uint   textureHeight;
    float3 wallCompensation;  // Applied to counteract physical wall color
};

// MARK: - Helpers

/// Convert sRGB gamma-encoded value to linear light.
inline float linearize(float v, float gamma) {
    return pow(max(v, 0.0f), gamma);
}

/// Convert linear light back to sRGB gamma-encoded value.
inline float delinearize(float v, float gamma) {
    return pow(max(v, 0.0f), 1.0f / gamma);
}

/// Compute luminance of a linear RGB color.
inline float luminance(float3 c) {
    return dot(c, float3(0.2126f, 0.7152f, 0.0722f));
}

// MARK: - Main Compute Kernel

kernel void zoneSampler(
    texture2d<float, access::sample>    inTexture      [[ texture(0) ]],
    device LEDColorOutput*              outBuffer      [[ buffer(0) ]],
    constant ZoneSamplerParams&         params         [[ buffer(1) ]],
    device const float2*                ledCoordinates [[ buffer(2) ]],
    uint                                gid            [[ thread_position_in_grid ]]
) {
    if (gid >= params.ledCount) return;

    constexpr sampler s(filter::linear, address::clamp_to_edge);

    const float W = float(params.textureWidth);
    const float H = float(params.textureHeight);
    const float depth = float(max(params.samplingDepth, 1u));

    float3 colorAccum = float3(0.0f);
    float  weightAccum = 0.0f;

    // Retrieve the normalized center coordinate for this LED
    float2 centerUV = ledCoordinates[gid];
    float2 centerPx = centerUV * float2(W, H);

    // Calculate a sampling bounding box centered around the LED coordinate.
    // If the point is on an edge (e.g. y=0), half the box extends outside the screen, 
    // and is clamped, resulting in sampling exactly `depth` pixels inwards.
    float2 boxExtents = float2(depth);
    float2 zoneMin = clamp(centerPx - boxExtents, float2(0.0f), float2(W, H));
    float2 zoneMax = clamp(centerPx + boxExtents, float2(0.0f), float2(W, H));

    // Sub-pixel sampling within the zone.
    const uint sqrtSamples = max(uint(sqrt(float(params.samplesPerZone))), 1u);
    const float2 zoneSize = max(zoneMax - zoneMin, float2(1.0f));

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

    // 1. Delinearize back to sRGB space for the LED strip (which expects gamma-encoded values)
    // Failing to do this causes a "double gamma" effect making LEDs incredibly dark.
    finalColor.r = delinearize(finalColor.r, params.gamma);
    finalColor.g = delinearize(finalColor.g, params.gamma);
    finalColor.b = delinearize(finalColor.b, params.gamma);

    // 2. Apply Saturation Boost to make colors "pop"
    // params.saturationBoost (ambientStrength) is 0.0 to 1.0.
    // We map 0.0 -> 1.0x (normal), 1.0 -> 2.0x (double saturation)
    float lumFinal = luminance(finalColor);
    float satMult = 1.0f + (params.saturationBoost * 1.0f);
    finalColor = mix(float3(lumFinal), finalColor, satMult);

    // 3. Prevent absolute black if there is some light on the screen
    // This creates a smoother ambient glow that doesn't just cut off abruptly
    if (lumFinal > 0.001f && lumFinal < 0.02f) {
        finalColor = max(finalColor, float3(0.02f)); // 2% minimum glow floor
    }
    
    // 4. Wall Color & White Balance Compensation
    finalColor *= params.wallCompensation;

    outBuffer[gid].r = saturate(finalColor.r);
    outBuffer[gid].g = saturate(finalColor.g);
    outBuffer[gid].b = saturate(finalColor.b);
    outBuffer[gid]._padding = 0.0f;
}

// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct GBufferOut {
    @location(0) pos: vec4f,
    @location(1) col: vec4f,
    @location(2) compressed: vec4f
}

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

//https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
fn OctWrap(v: vec2<f32>) -> vec2<f32> {
    var mult = -1.0;
    if (v.x >= 0.0 && v.y >= 0.0) {
        mult = 1.0;
    }
    return (1.0 - abs(v.yx)) * mult;
}
 
fn Encode(n: vec3<f32>) -> vec2<f32> {
    var encoded = n;
    encoded /= (abs(n.x) + abs(n.y) + abs(n.z));
    if (encoded.z < 0.0) {
        var newXY = OctWrap(encoded.xy);
        encoded.x = newXY.x;
        encoded.y = newXY.y;
    }
    encoded.x = encoded.x * 0.5 + 0.5;
    encoded.y = encoded.y * 0.5 + 0.5;
    return encoded.xy;
}

//https://stackoverflow.com/questions/6893302/decode-rgb-value-to-single-float-without-bit-shift-in-glsl
fn packColor(color: vec3<f32>) -> f32 {
    return (color.r + color.g * 256.0 + color.b * 256.0 * 256.0) / 2.0;
}

@fragment
fn main(in: FragmentInput) -> GBufferOut
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var octahedron_nor = Encode(in.nor);
    var packed_color = packColor((diffuseColor * 255.0).xyz);

    var transformedPos = cameraUniforms.viewProjMat * vec4(in.pos, 1.0);

    var out : GBufferOut;
    out.pos = vec4(in.pos, 1.0);
    out.col = vec4(diffuseColor);
    out.compressed = vec4(octahedron_nor.xy, f32(packed_color), transformedPos.z);

    return out;
}

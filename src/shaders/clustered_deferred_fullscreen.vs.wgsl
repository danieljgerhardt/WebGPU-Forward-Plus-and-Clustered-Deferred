// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

struct VertexInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{
    var out: VertexOutput;
    out.fragPos = cameraUniforms.viewProjMat * vec4(in.pos, 1);
    out.uv = in.uv;
    return out;
}
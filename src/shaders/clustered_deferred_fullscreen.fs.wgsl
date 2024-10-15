// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var gbuffer: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var gbufferSampler: sampler;

fn unpackColor(f: f32) -> vec3<f32> {
    var blue = floor(f / 256.0 / 256.0);
    var green = floor((f - blue * 256.0 * 256.0) / 256.0);
    var red = floor(f - blue * 256.0 * 256.0 - green * 256.0);
    // now we have a vec3 with the 3 components in range [0..255]. Let's normalize it!
    return vec3(blue, green, red) / 255.0;
}

fn Decode(f : vec2<f32>) -> vec3<f32> {
    var f_var = f * 2.0 - 1.0;
 
    // https://twitter.com/Stubbesaurus/status/937994790553227264
    var n = vec3(f_var.x, f_var.y, 1.0 - abs(f_var.x) - abs(f_var.y));
    var t = saturate(-n.z);
    if (n.x >= 0.0 && n.y >= 0.0) {
        n.x -= t;
        n.y -= t;
    } else {
        n.x += t;
        n.y += t;
    }
    return normalize(n);
}

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput, @builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4f
{
    let texDims = textureDimensions(gbuffer);
    var screenUV = vec2(fragCoord.x / f32(texDims.x), fragCoord.y / f32(texDims.y));
    var sample = textureSample(gbuffer, gbufferSampler, screenUV);
    var decodedNor = Decode(sample.xy);
    var unpackedColor = unpackColor(sample.z);

    var sampledDepth = sample.w;
    
    
    var ndc = vec4(screenUV * 2.0 - 1.0, sampledDepth, 1.0);
    var viewSpacePos = cameraUniforms.invProjMat * ndc;
    viewSpacePos /= viewSpacePos.w;

    let xFactor = 2.0 / f32(${numClustersX});
    let yFactor = 2.0 / f32(${numClustersY});
    let zFactor = f32(${numClustersZ});
    //var transformedPos = cameraUniforms.viewProjMat * vec4(in.pos, 1.0);
    //transformedPos /= transformedPos.w;
    var transformedPos = viewSpacePos;
    let clusterX = f32(transformedPos.x) * xFactor - 1.0;
    let clusterY = f32(transformedPos.y) * yFactor - 1.0;
    let clusterZ = f32(transformedPos.z) / zFactor;
    let clusterIdx = u32(clusterX + ${numClustersY} * clusterY + ${numClustersY} * ${numClustersZ} * clusterZ);
    let cluster = clusterSet.clusters[clusterIdx];

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) {
        let light = lightSet.lights[cluster.lights[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = unpackedColor.rgb * totalLightContrib;
    finalColor = vec3(screenUV.xy,0.0);
    return vec4(finalColor, 1.0);
}
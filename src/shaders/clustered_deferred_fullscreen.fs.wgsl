// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var gbufferPos: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var gbufferCol: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(5) var gbuffer: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(6) var depthTexture: texture_depth_2d;
@group(${bindGroup_scene}) @binding(7) var gbufferSampler: sampler;

/*fn unpackColor(f: f32) -> vec3<f32> {
    var blue = floor(f / 256.0 / 256.0);
    var green = floor((f - blue * 256.0 * 256.0) / 256.0);
    var red = floor(f - blue * 256.0 * 256.0 - green * 256.0);
    // now we have a vec3 with the 3 components in range [0..255]. Let's normalize it!
    return vec3(red, green, blue) / 255.0;
}*/
fn unpackColor(packed: f32) -> vec3<f32> {
    var color : vec3<f32>;
    var scaledPacked = 2.0 * packed;
    color.b = floor(scaledPacked / 256.0 / 256.0);
    color.g = floor((scaledPacked - color.b * 256.0 * 256.0) / 256.0);
    color.r = floor(scaledPacked - color.b * 256.0 * 256.0 - color.g * 256.0);
    // now we have a vec3 with the 3 components in range [0..255]. Let's normalize it!
    return color / 255.0;
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

fn view_from_screen_coord(invProjMat : mat4x4f, coord : vec2f, depth_sample: f32) -> vec3f {
  // reconstruct world-space position from the screen coordinate.
  let posClip = vec4(coord.x * 2.0 - 1.0, (1.0 - coord.y) * 2.0 - 1.0, depth_sample, 1.0);
  var posViewW = invProjMat * posClip;
  var posView = posViewW.xyz / posViewW.www;
  return posView;
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4f
{
    let texDims = textureDimensions(gbuffer);
    var screenUV = vec2(fragCoord.x / f32(texDims.x), fragCoord.y / f32(texDims.y));
    var sample = textureSample(gbuffer, gbufferSampler, screenUV);
    var decodedNor = Decode(sample.xy);
    var unpackedColor = unpackColor(sample.z);
    var diffuseColor = textureSample(gbufferCol, gbufferSampler, screenUV);

    if (diffuseColor.a < 0.5f) {
        discard;
    }

    /*var sampledDepth = textureSample(depthTexture, gbufferSampler, screenUV);
    var viewSpacePos = view_from_screen_coord(cameraUniforms.invProjMat, screenUV, sampledDepth);
    var modelSpacePos = cameraUniforms.invViewMat * vec4f(viewSpacePos, 1.0);

    /*let xFactor = 2.0 / f32(${numClustersX});
    let yFactor = 2.0 / f32(${numClustersY});
    let zFactor = f32(${numClustersZ});
    let clusterX = f32(viewSpacePos.x) * xFactor - 1.0;
    let clusterY = f32(viewSpacePos.y) * yFactor - 1.0;
    let clusterZ = f32(viewSpacePos.z) / zFactor;*/

    let posNDCSpaceW = cameraUniforms.viewProjMat * modelSpacePos;
    let posNDCSpace = posNDCSpaceW.xyz / posNDCSpaceW.www;
    let clusterX = u32((posNDCSpace.x + 1.0) * 0.5 * f32(${numClustersX}));
    let clusterY = u32((posNDCSpace.y + 1.0) * 0.5 * f32(${numClustersY}));
    let clusterZ = u32(f32(posNDCSpace.z) / f32(${numClustersZ}));*/

    let worldSpacePos = textureSample(gbufferPos, gbufferSampler, screenUV);
    let posNDCSpaceW = cameraUniforms.viewProjMat * worldSpacePos;
    let posNDCSpace = posNDCSpaceW.xyz / posNDCSpaceW.www;
    let clusterX = u32((posNDCSpace.x + 1.0) * 0.5 * f32(${numClustersX}));
    let clusterY = u32((posNDCSpace.y + 1.0) * 0.5 * f32(${numClustersY}));
    let clusterZ = u32(f32(posNDCSpace.z) / f32(${numClustersZ}));

    let clusterIdx = u32(clusterX + ${numClustersY} * clusterY + ${numClustersY} * ${numClustersZ} * clusterZ);
    let cluster = &clusterSet.clusters[clusterIdx];

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) {
        let light = lightSet.lights[cluster.lights[lightIdx]];
        totalLightContrib += calculateLightContrib(light, worldSpacePos.xyz, decodedNor);
    }

    var finalColor = diffuseColor.xyz * totalLightContrib;
    return vec4(finalColor, 1.0);
}
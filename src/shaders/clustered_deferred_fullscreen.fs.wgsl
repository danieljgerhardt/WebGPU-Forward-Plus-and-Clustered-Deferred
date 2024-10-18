// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var gbuffer: texture_2d<u32>;
@group(${bindGroup_scene}) @binding(4) var depthTexture: texture_depth_2d;

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

fn world_from_screen_coord(invViewProjMat : mat4x4f, coord : vec2f, depth_sample: f32) -> vec3f {
  // reconstruct world-space position from the screen coordinate.
  let posClip = vec4(coord.x * 2.0 - 1.0, (1.0 - coord.y) * 2.0 - 1.0, depth_sample, 1.0);
  let posWorldW = invViewProjMat * posClip;
  let posWorld = posWorldW.xyz / posWorldW.www;
  return posWorld;
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4f
{
    let texDims = textureDimensions(gbuffer);
    let texCoords = vec2u(fragCoord.xy);
    var screenUV = vec2(fragCoord.x / f32(texDims.x), fragCoord.y / f32(texDims.y));
    var sample = textureLoad(gbuffer, texCoords, 0u);

    var uint_nor = unpack2x16unorm(sample.x);
    var decodedNor = Decode(uint_nor);

    var diffuseColor = vec4f(f32(sample.y) / 255.0, f32(sample.z) / 255.0, f32(sample.w) / 255.0, 1.0);

    let sampleDepth = textureLoad(depthTexture, texCoords, 0u);
    let worldSpacePos = vec4f(world_from_screen_coord(cameraUniforms.invViewProjMat, screenUV, sampleDepth), 1.0);
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
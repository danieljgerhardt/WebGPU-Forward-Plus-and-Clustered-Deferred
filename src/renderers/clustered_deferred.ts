import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    GBufferSceneUniformsBindGroupLayout: GPUBindGroupLayout;
    GBufferSceneUniformsBindGroup: GPUBindGroup;

    finalPassSceneUniformsBindGroupLayout: GPUBindGroupLayout;
    finalPassSceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    GBufferTexture: GPUTexture;
    GBufferTextureView: GPUTextureView;
    GBufferTextureSampler: GPUSampler;

    GBufferPosTexture: GPUTexture;
    GBufferPosTextureView: GPUTextureView;

    GBufferColTexture: GPUTexture;
    GBufferColTextureView: GPUTextureView;

    GBufferPipeline: GPURenderPipeline;
    finalPassPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        this.GBufferSceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "gbuffer scene uniforms bind group layout",
            entries: [
                { // camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.GBufferSceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "gbuffer scene uniforms bind group",
            layout: this.GBufferSceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        this.GBufferTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.GBufferTextureView = this.GBufferTexture.createView();

        this.GBufferPosTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.GBufferPosTextureView = this.GBufferPosTexture.createView();

        this.GBufferColTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.GBufferColTextureView = this.GBufferColTexture.createView();

        this.GBufferTextureSampler = renderer.device.createSampler({
            magFilter: 'linear',
            minFilter: 'linear',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge'
        });

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.depthTextureView = this.depthTexture.createView();

        this.finalPassSceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "final pass scene uniforms bind group layout",
            entries: [
                { // camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { //g buffer pos
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "float",
                        viewDimension: "2d"
                    }
                },
                { //g buffer col
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "float",
                        viewDimension: "2d"
                    }
                },
                { // g buffer tex
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { 
                        sampleType: "float",
                        viewDimension: "2d"
                     }
                },
                { // depth stencil
                    binding: 6,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "depth",
                        viewDimension: "2d"
                    }
                },
                { // texSampler
                    binding: 7,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: "filtering" }
                }
            ]
        });

        this.finalPassSceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "final pass scene uniforms bind group",
            layout: this.finalPassSceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                },
                {
                    binding: 3,
                    resource: this.GBufferPosTextureView
                },
                {
                    binding: 4,
                    resource: this.GBufferColTextureView
                },
                {
                    binding: 5,
                    resource: this.GBufferTextureView
                },
                {
                    binding: 6,
                    resource: this.depthTextureView
                },
                {
                    binding: 7,
                    resource: this.GBufferTextureSampler
                }
            ]
        });
    
        this.GBufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "gbuffer pipeline layout",
                bindGroupLayouts: [
                    this.GBufferSceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "gbuffer vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    {
                        format: "rgba16float"
                    },
                    {
                        format: "rgba16float"
                    },
                    {
                        format: "rgba16float"
                    }
                ]
            }
        });

        this.finalPassPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "final pass pipeline layout",
                bindGroupLayouts: [
                    this.finalPassSceneUniformsBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "final pass vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                })
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "final pass clustered deferred frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat
                    }
                ]
            }
        });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        const encoder = renderer.device.createCommandEncoder();

        // - run the clustering compute shader
        this.lights.doLightClustering(encoder);

        // - run the G-buffer pass, outputting position, albedo, and normals
        const GBufferRenderPass = encoder.beginRenderPass({
            label: "gbuffer render pass",
            colorAttachments: [
                {
                    view: this.GBufferPosTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.GBufferColTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.GBufferTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        GBufferRenderPass.setPipeline(this.GBufferPipeline);

        GBufferRenderPass.setBindGroup(shaders.constants.bindGroup_scene, this.GBufferSceneUniformsBindGroup);

        this.scene.iterate(node => {
            GBufferRenderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            GBufferRenderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            GBufferRenderPass.setVertexBuffer(0, primitive.vertexBuffer);
            GBufferRenderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            GBufferRenderPass.drawIndexed(primitive.numIndices);
        });

        GBufferRenderPass.end();

        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        const finalRenderPass = encoder.beginRenderPass({
            label: "final render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ]
        });

        finalRenderPass.setPipeline(this.finalPassPipeline);

        finalRenderPass.setBindGroup(shaders.constants.bindGroup_scene, this.finalPassSceneUniformsBindGroup);
        finalRenderPass.draw(6);

        finalRenderPass.end();

        renderer.device.queue.submit([encoder.finish()]);

    }
}

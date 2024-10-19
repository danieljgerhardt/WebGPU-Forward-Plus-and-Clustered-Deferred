WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Daniel Gerhardt
  * https://www.linkedin.com/in/daniel-gerhardt-bb012722b/
* Tested on: **Google Chrome 129.0.6668.101** on
  Windows 23H2, AMD Ryzen 9 7940HS @ 4GHz 32GB, RTX 4070 8 GB (Personal Laptop)

### Live Demo

[![](img/thumb.png)](http://TODO.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

### Demo Video/GIF

[![](img/video.mp4)](TODO)

### Description

This project is an implementation of 3 different render modes using WebGPU. The modes are:
- Naive
  - The naive render uses a standard forward rendering pipeline which runs through each light for each pixel to do lighting computations.
- Forward+
  - The forward+ renderer increases performance by dividing the screen into clusters. A compute shader assigns eaach of these clusters the lights that act within its region, up to a certain maximum. Then the rendering is done in one pass, where each fragment is placed into a cluster and only does computations for the lights in that cluster.
- Clustered Deferred
  - The clustered deferred renderer is similar to Forward+ but with the addition of deferred rendering. In the first pass, the depth, normal, and color are written to a single 4 channel texture. Then, in the second pass, the position is reconstructed from depth, and the same lighting strategy from Forward+ is used.

To toggle between the modes or change the number of lights, use the controls at the top right of the page.

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)

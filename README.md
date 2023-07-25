# Unity Stylized Grass Shader 

### Description

This shader uses stochastic sampling which is defined in its first function. 
Inside the vertex shader, there is a function called `geom`, which creates additional geometry, that later gets distorted. It also calculates the fade distance (an LOD approach that can be used for large terrain meshes) between the camera and the vertex location. In the same location, it defines the custom normal vector and adds it to the existing normal.
In the fragment shader, the distortion is calculated and applied over time. The multi-texture tiling is assembled and the color and texture are composed. At the end, the distortion gets applied to the color too.
I've added a `SHADOW_CASTER` pass that is used for enhancing the effects of the shader, but I've disabled it in the default for faster testing.


**Textures Used:** https://www.artstation.com/artwork/lv6qG

To-Do:
- [x] Basic Grass
- [x] Normals
- [x] Wind
- [x] Level of Detail Fade
- [x] Tiling
- [ ] [Edge Bevel](https://www.quizcanners.com/single-post/2018/02/08/mobile-friendly-bevel-shader-unity)
- [ ] [Level of Detail Subshaders](https://docs.unity3d.com/2018.3/Documentation/Manual/SL-ShaderLOD.html)


### How to Use:

This shader's properties are divided in multiple sections for easier access: **Tint Colors**, **Textures**, **Geometry Values**, **Grass Values** and **Level of Detail**.

In the **Tint Colors** section, the user is able to pick their desired tint, the shadow color and the saturation of the grass.

![image](https://github.com/nglk99/uma-technical-task/assets/46087451/14443d04-2db7-49d9-8623-3640f77151ed)

Under the **Textures** section, it is possible to tweak the main texture of the material, along with the grass pattern, noise and wind distortion textures. Here one can pick the tile of the main texture.

![image](https://github.com/nglk99/uma-technical-task/assets/46087451/a82ee446-f5bb-41ad-a076-f4c1b46f5588)

The **Geometry Values** section contains the displacement settings, the minimum and amount of grass displacement, as well as the offset by normal or offset by direction vector.

![image](https://github.com/nglk99/uma-technical-task/assets/46087451/0cb340ba-b996-4864-9b6d-308a4089db1b)

**Grass Values** is the section with additional settings such as wind speed and direction, grass thinness and noise power. This section offers three more tiling methods.

![image](https://github.com/nglk99/uma-technical-task/assets/46087451/66a96f0f-5673-41ea-9f21-17593c199044)

Finally, the **Level of Detail** section contains the direction at which the shader effects start to fade.

![image](https://github.com/nglk99/uma-technical-task/assets/46087451/2bf5e28c-3db5-4349-9fba-93257a10222e)


Here's what this means in action (displacement exaggerated for demonstration purposes) :

![LOD_Left](https://github.com/nglk99/uma-technical-task/assets/46087451/c6769994-ea74-43fb-a98f-de6333516715)


Issues:
- [ ] URP issue - shader works in game view, but is rendered transparent in scene view
![image](https://github.com/nglk99/uma-technical-task/assets/46087451/7fd8568e-75d7-423d-8d25-9676616a5028)


# Radiosity Engine
A simple rendering engine that works by applying the finite element method to solve the rendering equation for the given scene. 

To actually render the scene, open a MATLAB terminal (using the MATLAB Interactive Terminal extension) and type the following commands:
```
>>> [vertices, faces, reflectivities, emissions, objectMap] = read_obj_file("scene.obj")

>>> visibilityMatrix = readmatrix("scene.txt")

>>> colors = light_scene(vertices, faces, reflectivities, emissions, visibilityMatrix)

>>> renderData(vertices, faces, colors)
```

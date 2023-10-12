# Radiosity Engine
A simple rendering engine that works by applying the finite element method to solve the rendering equation for the given scene. 

To actually render the scene, open a MATLAB terminal (using the MATLAB Interactive Terminal extension) and type the following commands:
```
>>> [vertices, faces, reflectivities, emissions, object_map] = read_obj_file("scene.obj")

>>> visibility_matrix = readmatrix("scene.txt")

>>> colors = light_scene(vertices, faces, reflectivities, emissions, visibility_matrix)

>>> renderData(vertices, faces, colors)
```

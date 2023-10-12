# Radiosity Engine
A simple rendering engine that works by applying the finite element method to solve the rendering equation for the given scene. 

To actually render the scene, open a MATLAB terminal (using the MATLAB Interactive Terminal extension) and type the following commands:
```
>>> [vertices, faces, reflectivities, emissions, objectMap] = read_obj_file("scene.obj")

>>> visibilityMatrix = readmatrix("scene.txt")

>>> colors = light_scene(vertices, faces, reflectivities, emissions, visibilityMatrix)

>>> render_scene(vertices, faces, colors)
```
To render a custom scene, create your scene with any 3D model building software (such as 3D Builder) and save the scene as "scene.obj" file (and the .mtl file as "scene.mtl" if you have one). Don't spend much time on the texture, since this engine ignores the texture of the objects in the scene. Drop the files into the root directory of this engine and type the following commands into a bash terminal:
```
$ gcc compute_visibility.c -o compute_visibility -lm fopenmp

$ ./compute_visibility scene.obj scene.vis
```
You'll need to convert the matrix from the .vis format to a .txt format using some other software. Then open a MATLAB terminal and run the same four commands as above.

The mathematics behind the engine are included in the file "math.pdf".

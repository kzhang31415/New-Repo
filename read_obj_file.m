function [vertices,faces,reflectivities,emissions,objectMap]=read_obj_file(objfile, silent)
    %function [vertices,faces,reflectivities,emissions,objectMap]=read_obj_file(objfile, silent)
    %
    %Read an obj file.  Supports the non-standard #light <power> feature.
    %
    %INPUT -
    %objFile - The name of an obj file you need read.  If the .obj file references a .mtl file, the .mtl file will indeed be parsed.
    %silent - an optional argument, with default 0.  If set to 1 then we don't print anything.
    %
    %OUTPUT -
    %
    %vertices - N x 3 list of vertices.  In the form vertices=[v1x, v1y, v1z;
    %                                                              v2x, v2y, v2z;
    %                                                              v3x, v3y, v3z;
    %                                                               .   .      .;
    %                                                              vNx, vNy, vNz];
    %
    %faces - an M x 3 list of faces. Face i is the triangle connecting vertices vi1, vi2, vi3.
    %           so if F(5,:) is [8, 13, 109] then face 5 is a triangle whose vertex coordinates can be found in
    %           V(8,:), V(13,:), and V(109,:).
    %
    %
    %reflectivities - an M x 3 list of reflectances for each face.  If reflectivities(5,:) = [0.2, 0.9, 0.4]
    %            then face 5 reflects 20% of red light that impinges upon it, 90% of the green light, and 40% of the blue light. If no color for a face is
    %            given, then value [249, 246, 238] is the default color.
    %
    %emissions - an M x 3 list of emissions.  If emissions(5,:) = [4,9,230] then face 5 is emitting 4/sec red, 9/sec green, and 230/sec blue light.
    %
    %objectMap - A container grouping faces to "objects" as defined by the .obj file.  If, for example, there is an object named "car", then
    %            objectMap("car") is a vector containing all faces which are part of the car object.
    
    
    if ~exist('silent','var') || isempty(silent)
        silent=0;
    end
    
    %Read an obj file.
    [fid,message]=fopen(objfile);
    
    if fid<0
        fprintf(2,'Error opening %s: %s\n',objfile,message);
        return;
    end
    
    
    line=fgetl(fid);
    vertexCount=0;
    faces=[];
    normalList=[];
    normalIdx=[];
    reflectivities=[];
    emissions=[];
    
    warnvt=0;
    warnvc=0;
    warnmat=0;
    warnvn=0;
    warnpoly=0;
    warngroup=0;
    warnobject=0;
    warnshade=0;
    
    fixedPolygons=0;
    fixedPolyCount=0;
    polyToTriCount=0;
    
    materialLibraryFile='';
    mtlLib=containers.Map({'default'},{[0.9,0.9,0.9]});
    currentMaterial='default';
    
    vertexColorList=[];
    vertexColorIsNonDefault=[];
    
    facesWMaterialColor=0;
    facesWVertexColor=0;
    facesWDefaultColor=0;
    currentObject='defaultObject';
    objectMap=containers.Map();
    objectMap(currentObject)=[];
    
    lightingOn=0;
    litFaces=0;
    lightingPower=0;
    
    while ~feof(fid)
        line=strtrim(line);
        %Only process the line if it is non-empty and non-comment
        if ~isempty(line)
            parts=strsplit(line);
            switch parts{1}
                case 'g'
                    warngroup=1;
                case 'o'
                    %warnobject=1;
                    currentObject=parts{2};
                    objectMap(currentObject)=[];
                    lightingOn=0;
                case '#light'
    
                    lightingOn=1;
                    if numel(parts)>1
                        lightingPower=str2num(parts{2});
                    else
                        lightingPower=150;
                    end
                case '#endlight'
                    lightingOn=0;
    
                case 'mtllib'
                    materialLibraryFile=parts{2};
                    if ~silent
                        fprintf('Using material library %s\n',materialLibraryFile);
                    end
                    mtlLib=parse_material_library(materialLibraryFile);
                case 'usemtl'
                    currentMaterial=parts{2};
                case 's'
                    warnshade=1;
                case 'v'
                    vertexCount=vertexCount+1;
                    vertices(vertexCount,:)=[str2double(parts{2}), str2double(parts{3}), str2double(parts{4})];
                    %There is a vertex coloring on this line.
                    if numel(parts)>4
                        vertexColorList(vertexCount,:)=[str2double(parts{5}), str2double(parts{6}), str2double(parts{7})];
                        vertexColorIsNonDefault(vertexCount)=1;
                        useVertexColoring=1;
                    end
                case 'vt' %Specifying a vertex texture -- bad news.
                    warnvt=1;
                case 'vn' %Specfiying a vertex normal vector -- save for later use.
                    normalList(end+1,:)=[str2double(parts(2)) str2double(parts(3)) str2double(parts(4))];
                case 'f'  %Specifying a face, gotta figure out exactly how they are specifying
                    vtx_spec=[];
                    for i=2:numel(parts)  %Iterate over each vertex
                        vtx_split=strsplit(parts{i},'/');  %split on /, maybe there is vertex normal or material information
                        for j=1:numel(vtx_split)        %For each component, put it in the vtx_spec matrix.  It will go vertex index | material index | normal index
                            if ~isempty(vtx_split{j})
    
                                vtx_spec(i-1,j)=str2num(vtx_split{j});  %Convert to a number.
    
                            end
                        end
                    end
    
                    if size(vtx_spec,1)>3  %This is not a triangle!
                        if fixedPolygons==0
                            fprintf(2,'Warning! Polygonal face detected.  Breaking into triangles -- this may take some time if there are many polygonal faces.\n');
                        end
                        fixedPolygons=1;
                        fixedPolyCount=fixedPolyCount+1;
    
                        warnpoly=1; v1=0;v2=0;v3=0;v4=0;
    
                        vertex_coordinates=vertices(vtx_spec(:,1),:)';  %Coordinates of the vertices in this polygon.
                        vertex_coordinates=vertex_coordinates-repmat(vertex_coordinates(:,1),1,size(vertex_coordinates,2)); %Translate all coordinates so the first one is at the origin.
                        %Rotate all vertices down into the x-y plane.
                        %Theoretically at least.
                        [A,B]=qr(vertex_coordinates(:,2:end));
                        vertex_coordinates=[vertex_coordinates(:,1), B];
                       % vertex_coordinates=HouseholderReflector(vertex_coordinates(:,2))*vertex_coordinates; %Rotate out the 2nd column (first is already at origin) to be [1;0;0]
                        %vertex_coordinates(2:3,:)=HouseholderReflector(vertex_coordinates(2:3,3))*vertex_coordinates(2:3,:); %Rotate out the 3rd column to be [x;1;0]
                        %Now, assuming the original polygon was planar, the 3rd
                        %coordinate for all vertices should be 0.  Check, then
                        %delete.
    
                        %This test was here to test to make sure that the face
                        %was actually planar.  But it seems, because of the
                        %limited precision with which the vertices were written
                        %to file, that this fails a lot.  Just go with it??!?
                        %if any(abs(B(3,:))>0.1*sqrt(sum(B.^2,1)))
                        %    fprintf(2,'Error, polygon specified by %s does not appear to be planar, IDK what to do. So I''ll quit.\n',line);
                        %    return;
                        %end
                        vertex_coordinates(3,:)=[];
                        %Do delaunay triangulation.
                        dt=delaunay(vertex_coordinates');
    
                        %Now add the triangulation from delaunay to the
                        %FaceList. Remember to adjust vertex coordinates.
                        %if the triangles don't have a normal vector that
                        %matches the original normal vector, swap two of them.
    
                        original_normal=cross(vertices(vtx_spec(2,1),:)-vertices(vtx_spec(1,1),:), vertices(vtx_spec(3,1),:)-vertices(vtx_spec(1,1),:));
    
                        facesToAdd=[];
                        for i=1:size(dt,1)
                            triangle_normal=cross(vertices(vtx_spec(dt(i,2),1),:)-vertices(vtx_spec(dt(i,1),1),:), vertices(vtx_spec(dt(i,3),1),:)-vertices(vtx_spec(dt(i,1),1),:));
                            if triangle_normal(1)*original_normal(1)<0
                                tmp=dt(i,2);
                                dt(i,2)=dt(i,1);
                                dt(i,1)=tmp;
                            end
                            facesToAdd(end+1,:)=[vtx_spec(dt(i,1),1) vtx_spec(dt(i,2),1) vtx_spec(dt(i,3),1)];
                        end
                        polyToTriCount=polyToTriCount+size(dt,1);
                    else  %This is a triangle.  Hope for this.
                        facesToAdd=vtx_spec(:,1)';
                    end
    
                    %Now actually add.
                    for i=1:size(facesToAdd,1)
                        faces(end+1,:)=facesToAdd(i,:);
                        if size(vtx_spec,2) == 3 && vtx_spec(1,3) ~= 0
                                %normalIdx(end+1,:)=vtx_spec(facesToAdd(i,:)',3)';
                        end
                        if length(vertexColorIsNonDefault)>= max(facesToAdd(i,:)) && all(vertexColorIsNonDefault(facesToAdd(i,:)))
                            reflectivities(end+1,:)=mean(vertexColorList(facesToAdd(i,:),:));
                            facesWVertexColor=facesWVertexColor+1;
                        else
                            try
                                reflectivities(end+1,:)=mtlLib(currentMaterial);
                            catch e
                                e;
                            end
                            facesWMaterialColor=facesWMaterialColor+1;
                            if strcmp('default',currentMaterial)
                                facesWDefaultColor=facesWDefaultColor+1;
                            end
                        end
    
                        try
                        objectMap(currentObject)=[objectMap(currentObject), size(faces,1)];
                        catch e
                            e;
                        end
                        if lightingOn
                            emissions(end+1,:)=reflectivities(end,:)*lightingPower;
                            litFaces=litFaces+1;
                        else
                            emissions(end+1,:)=[0,0,0];
                        end
    
                    end
                otherwise
                    if ~isempty(parts{1}) && parts{1}(1)~='#'
                        fprintf(2,'Error, I do not know how to parse:\n%s\n',line);
                        return;
                    end
            end
        end
        line=fgetl(fid);
    end
    
    if warnmat
        fprintf(2,'Warning: %s included material information, which is not supported by this reader.\n',objfile);
    end
    
    if warnvt
        fprintf(2,'Warning: %s included vertex texture information, which is not supported by this reader.\n',objfile);
    end
    
    if warnvc
        fprintf(2,'Warning: %s included vertex color information, which is not supported by this reader.\n',objfile);
    end
    
    if warnvn
        fprintf(2,'Warning: %s includes vertex normal information, which is not supported by this reader.\n',objfile);
    end
    
    if warnpoly
        fprintf(2,'Warning: %s contains non-triangle faces; support for which is experimental.\n',objfile);
    end
    
    if warngroup
        fprintf(2,'Warning: %s contains groups of faces, which I do not know what to do with.\n',objfile);
    end
    
    if warnobject
        fprintf(2,'Warning: %s contains an object name.  I don''t know what to do with that.\n',objfile);
    end
    
    if warnshade
        fprintf(2,'Warning: %s contains shading instructions, which I ignore.\n',objfile);
    end
    
    
    
    fclose(fid);
    
    if ~silent
        fprintf('File: %s\n',objfile);
        fprintf('Material Library:%s\n',materialLibraryFile);
        fprintf('Vertices: %d\n',size(vertices,1));
        fprintf('Faces: %d\n',size(faces,1));
        fprintf('Vertex Normals: %d\n',size(normalList,1));
        fprintf('Faces with vertex normals defined: %d\n',size(normalIdx,1));
        fprintf('Faces with default coloring: %d\n',facesWDefaultColor);
        fprintf('Faces with vertex color:%d\n',facesWVertexColor);
        fprintf('Faces with material color: %d\n',facesWMaterialColor);
        fprintf('Faces that are lit: %d\n',litFaces);
        if fixedPolygons
            fprintf('Warning: I found %d polygonal faces, which I broke into %d triangles.  This is experiemental!\n', fixedPolyCount, polyToTriCount);
        end
    end
    
    
        function lib=parse_material_library(fname)
            [myfid,errmsg] = fopen(fname,'r');
            lib=containers.Map({'default'},{[0.9,0.9,0.9]});
            if myfid<0
                fprintf(2,'Error opening %s: %s\n',fname,errmsg);
            end
    
            while ~feof(myfid)
                myline=strtrim(fgetl(myfid));
                mylineparts=strsplit(myline);
                switch mylineparts{1}
                    case 'newmtl'
                        currentMaterialName=mylineparts{2};
                        lib(currentMaterialName)=[0,0,0];
                    case 'Ka'
                        lib(currentMaterialName)=lib(currentMaterialName)+[str2double(mylineparts{2}) str2double(mylineparts{3}) str2double(mylineparts{4})];
    
                    case 'Kd'
                        lib(currentMaterialName)=lib(currentMaterialName)+[str2double(mylineparts{2}) str2double(mylineparts{3}) str2double(mylineparts{4})];
                    %case 'Ks'
                    %    lib(currentMaterialName)=lib(currentMaterialName)+[str2double(mylineparts{2}) str2double(mylineparts{3}) str2double(mylineparts{4})];
                end
            end
    
            allColorsArePercents=1;
            for m=lib.keys()
                if any(lib(m{1})>1)
                    allColorsArePercents=0;
                end
            end
    
            if allColorsArePercents
                fprintf(2,'Warning: All colors in %s appear to be in 0-1 range, while vertex colors are usually in 0-256 range.  Adjusting lib colors.\n',fname);
                for m=lib.keys()
                    lib(m{1})=lib(m{1})*256;
                end
            end
    
    
            fclose(myfid);
        end
    
    
    end
    
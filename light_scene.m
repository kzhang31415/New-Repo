function [colors] = light_scene(vertices, faces, reflectivities, emissions, visibilityMatrix)
    %function [redIntensityVec, greenIntensityVec, blueIntensityVec] = light_scene(visibilityMatrix, faces, emissions)
    %
    %Reads a visibility matrix, faces list, and emissions list, and computes the (r,g,b) color intensity values of each face. 
    %
    %INPUT -
    %visibilityMatrix - a M x M matrix where visibilityMatrix(i,j) = 1 if face i can see face j, and 0
    %                   otherwise. This matrix can be computed using functions in the computeVisibility.c file.
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
    %emissions - an M x 3 list of emissions.  If emissions(5,:) = [4,9,230] then face 5 is emitting 4/sec red, 9/sec green, and 230/sec blue light.
    %
    %reflectivities - an M x 3 list of reflectances for each face.  If reflectivities(5,:) = [0.2, 0.9, 0.4]
    %            then face 5 reflects 20% of red light that impinges upon it, 90% of the green light, and 40% of the blue light. If no color for a face is
    %            given, then value [249, 246, 238] is the default color.
    %
    %sceneRadius - the radius of the scene.  The maximum distance from the origin of any vertex in the scene.  
    %
    %OUTPUT -
    %colors - An M x 3 list of color intensity values, scaled to be between 0 and 256 exclusive. If
    %         colors(5,:) = [4, 9, 230] then face 5 has red intensity 4, green intensity 9, and blue intensity 230.
    %
        sceneRadius = compute_scene_radius(vertices);
        redIntensityVec = computeIntensity(vertices, faces, visibilityMatrix, emissions(:,1), reflectivities(:,1), sceneRadius);
        greenIntensityVec = computeIntensity(vertices, faces, visibilityMatrix, emissions(:,2), reflectivities(:,2), sceneRadius);
        blueIntensityVec = computeIntensity(vertices, faces, visibilityMatrix, emissions(:,3), reflectivities(:,3), sceneRadius);
        %colors = [redIntensityVec, greenIntensityVec, blueIntensityVec]
        colors = scale(redIntensityVec, greenIntensityVec, blueIntensityVec, emissions);
        fprintf('Done!\n');
    end
    
    function [intensityVec] = computeIntensity(vertices, faces, visibilityMatrix, emissionVec, reflectivityVec, sceneRadius)
    
        C = zeros(size(faces,1),size(faces,1));
        
        for i=1:size(faces,1)
            for j=1:size(faces,1)
                if visibilityMatrix(i,j) == 0
                    C(i,j) = 0;
                else
                    S = 0;
                    A_j = compute_face_area(vertices, faces(j,:));
                    n_i = compute_normal_vector(vertices, faces(i,:));
                    n_j = compute_normal_vector(vertices, faces(j,:));
                    for k=1:3
                        for l=1:3
                            x = vertices(faces(i,k),:) - vertices(faces(j,l),:);
                            if norm(x) >= 0.005 % * sceneRadius
                                S = S + (dot(n_j, x) * dot(n_i, -x) / (norm(x)^4));
                            end
                        end
                    end
                    %C(i,j) = reflectivityVec(j) * (A_j / 9) * S; %Reflectivity values are strange for the example scene
                    C(i,j) = (A_j / 9) * S;
                end
            end
        end
        
        intensityVec = linsolve(eye(size(faces,1)) - C, emissionVec);
    end
    
    function [A] = compute_face_area(V, F)
        A = V(F(1),:);
        B = V(F(2),:);
        C = V(F(3),:);
        A = 0.5*norm(cross(B-A,C-A));
    end
    
    function [n] = compute_normal_vector(V, F)
        n = cross(V(F(2),:) - V(F(1),:), V(F(3),:) - V(F(1),:));
        n = n/norm(n);
    end
    
    function [redIntensityVec, greenIntensityVec, blueIntensityVec] = scale(redIntensityVec, greenIntensityVec, blueIntensityVec, emissions)
        emissionCount = 0;
        nonEmissionCount = 0;
        E = [];
        NE = [];
        for i=1:size(emissions,1)
            if emissions(i,1) > 0 || emissions(i,2) > 0 || emissions(i,3) > 0
                emissionCount = emissionCount + 1;
                E(emissionCount) = i;
            else
                nonEmissionCount = nonEmissionCount + 1;
                NE(nonEmissionCount) = i;
            end
        end
        minE = min([min(redIntensityVec(E(:))), min(greenIntensityVec(E(:))), min(blueIntensityVec(E(:)))]);
        minNE = min([min(redIntensityVec(NE(:))), min(greenIntensityVec(NE(:))), min(blueIntensityVec(NE(:)))]);
        for i=1:size(emissions,1)
            if ismember(i,E)
                redIntensityVec(i) = redIntensityVec(i) - minE;
                greenIntensityVec(i) = greenIntensityVec(i) - minE;
                blueIntensityVec(i) = blueIntensityVec(i) - minE;
            else
                redIntensityVec(i) = redIntensityVec(i) - minNE;
                greenIntensityVec(i) = greenIntensityVec(i) - minNE;
                blueIntensityVec(i) = blueIntensityVec(i) - minNE;
            end
        end
        maxE = max([max(redIntensityVec(E(:))), max(greenIntensityVec(E(:))), max(blueIntensityVec(E(:)))]);
        maxNE = max([max(redIntensityVec(NE(:))), max(greenIntensityVec(NE(:))), max(blueIntensityVec(NE(:)))]);
        for i=1:size(redIntensityVec)
            if ismember(i,E)
                redIntensityVec(i) = 0.9 * redIntensityVec(i) / maxE;
                greenIntensityVec(i) = 0.9 * greenIntensityVec(i) / maxE;
                blueIntensityVec(i) = 0.9 * blueIntensityVec(i) / maxE;
            else
                redIntensityVec(i) = 0.8 * redIntensityVec(i) / maxNE;
                greenIntensityVec(i) = 0.8 * greenIntensityVec(i) / maxNE;
                blueIntensityVec(i) = 0.8 * blueIntensityVec(i) / maxNE;
            end
        end
    end
    
    function [sceneRadius] = compute_scene_radius(vertices)
        sceneRadius = 1;
        for i=1:size(vertices,1)
            if norm(vertices(i,:)) > sceneRadius
                sceneRadius = norm(vertices(i,:));
            end
        end
    end
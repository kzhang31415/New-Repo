function render_scene(V,F,C)
    %function renderData(V,F,C)
    %
    %display the scene that has vertices V and faces F and colors C. 
    %
    %C is optional, if it is not specified then everything is drawn grey.
        if ~exist('C','var')|| isempty(C)
            C=repmat([211,211,211],size(F,1),1);
        end
    
        figure();
    
        %Scale C so that its max color is 0.99. 
        C=0.99*C/max(C(:));
    
        P=patch('Faces',F,'Vertices',V,'FaceVertexCData',C,'EdgeColor','none','FaceColor','flat');
        axis equal
        
        %P.FaceColor='flat'
        %P.EdgeColor='none'
        view(18,15);
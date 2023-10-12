#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>


typedef struct {
	float point1[3];
	float point2[3];
	float point3[3];
	float normal[3];
	float center[3];
	float color[3];
}patch;


int main(int argc, char** argv)
{
    patch* patchList;
    int nPatches;
    if (argc<3){
        fprintf(stderr,"Usage: computeVisiblity <input .obj file> <output .vis file>\n");
        exit(1);
    }
    read_obj_file(argv[1],&patchList,&nPatches);
    int* vis=malloc(nPatches*nPatches*sizeof(int));
	make_vis(patchList,nPatches,vis);
	printf("Finished computing visibility, writing results.\n");
	write_vis(argv[2],vis,nPatches);
    return 1;
}


void print_v(float* v){
	printf("(%f %f %f)",v[0],v[1],v[2]);
}


void normalize(float* n,float* answer){
	float size=sqrt(pow(n[0],2)+pow(n[1],2)+pow(n[2],2));
	answer[0]=n[0]/size;
	answer[1]=n[1]/size;
	answer[2]=n[2]/size;
}


void vector_vector_minus(float* a, float* b,float* answer){
	answer[0]=a[0]-b[0];
	answer[1]=a[1]-b[1];
	answer[2]=a[2]-b[2];
}
	

void vector_scalar_multiply(float* v, float s,float* ans){
	ans[0]=v[0]*s;
	ans[1]=v[1]*s;
	ans[2]=v[2]*s;
}


void cross (float* a, float* b, float* answer){
	answer[0]=(a[1]*b[2] - a[2]*b[1]);
	answer[1]=(a[2]*b[0] - a[0]*b[2]);
	answer[2]=(a[0]*b[1] - a[1]*b[0]);
}


void vector_vector_add(float *a, float* b, float* answer){
	answer[0]=a[0]+b[0];
	answer[1]=a[1]+b[1];
	answer[2]=a[2]+b[2];
}


void find_normal(patch* P){
	float norm[3];
	float twomone[3];
	float threemone[3];
	vector_vector_minus(P->point2,P->point1,twomone);
	vector_vector_minus(P->point3,P->point1,threemone);
	
	cross(twomone,threemone,norm);
	normalize(norm,norm);
	normalize(norm,P->normal);
}

float dot(float *a,float *b){
	return a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
}


int same_side(float *p1, float* p2, float* a, float* b){
    float cp1[3];
    float cp2[3];
    float bma[3];
	float p1ma[3];
	float p2ma[3];
	vector_vector_minus(p1,a,p1ma);
	vector_vector_minus(p2,a,p2ma);
	vector_vector_minus(b,a,bma);
	cross(bma,p1ma,cp1);
	cross(bma,p2ma,cp2);

    if (dot(cp1,cp2) >= 0){ 
        return 1;
    }
    else{ 
        return 0;
    }

}


int point_in_patch(float* p, float* a, float* b, float* c){
    if (same_side(p,a, b,c) && same_side(p,b, a,c)&& same_side(p,c, a,b)) {
         return 1;
    }
    else{
        return 0;
    }

}


int read_obj_file(char* filename,patch** patchList, int* finalPatchCount){
    printf("Opening %s for read.\n",filename);
    FILE* fp=fopen(filename,"r");
    if (fp==NULL){
        fprintf(stderr,"Error opening %s for reading. Abort!\n",filename);
        exit(1);
    }

    int maxLineSize=4096;
    char line[maxLineSize];

    int vertexCapacity=5;
    int vertexIncrement=7;
    int faceCapacity=1;
    int faceIncrement=3;
    float* vertexListFlat= malloc(3000*3*sizeof(float));
    float (*vertexList)[3] = (float (*)[3]) vertexListFlat;

    *patchList=malloc(faceCapacity*sizeof(patch));

    int nVertices=0;
    int nFaces=0;

    int tokensRead=0;
     
    int d1, d2, d3, d4;

    float AB[3];
    float AC[3];
    float tmpN[3];

    while (fgets(line,maxLineSize,fp)!=NULL){
        if (strlen(line)>=2 && line[0]=='v' && line[1]==' '){
                if (nVertices==vertexCapacity){
                    vertexCapacity+=vertexIncrement;
                    vertexListFlat=realloc(vertexListFlat,vertexCapacity*3*sizeof(float));
                    vertexList = (float (*)[3]) vertexListFlat;
                }
                tokensRead=sscanf(line,"v %f %f %f",&vertexList[nVertices][0],&vertexList[nVertices][1],&vertexList[nVertices][2]);
                if (tokensRead!=3){
                    fprintf(stderr,"Error reading %s:\nLine: %s\nExpected to read 3 floats, instead read %d.\n",filename,line,tokensRead);
                    exit(1);
                }
                nVertices++;
        }

        if (strlen(line)>=2 && line[0]=='f'){
            if (nFaces==faceCapacity){
                faceCapacity+=faceIncrement;
                *patchList=realloc(*patchList,faceCapacity*sizeof(patch));
            }
            tokensRead=sscanf(line,"f %d %d %d %d",&d1, &d2, &d3, &d4);
            if (tokensRead<3){
                tokensRead=sscanf(line,"f %d/%*d %d/%*d %d/%*d %d/%*d", &d1, &d2, &d3, &d4);
                if (tokensRead<3){
                    tokensRead=sscanf(line,"f %d/%*d/%*d %d/%*d/%*d %d/%*d/%*d %d/%*d/%*d",&d1, &d2, &d3, &d4);
                    if (tokensRead<3){
                        tokensRead=sscanf(line,"f %d//%*d %d//%*d %d//%*d %d//%*d",&d1, &d2, &d3, &d4);
                    }
                }

            }

            if (tokensRead>3){
                fprintf(stderr,"Error reading line %s: too many vertices listed in this face; this reader can only handle trianglar faces.  Recommend opening in some other tool and resaving; this will often result in a purely triangular mesh.\n",line);
                exit(1);
            }

            if (tokensRead<3){
                fprintf(stderr,"Error reading line %s: couldn't find 3 vertices.",line);
                exit(1);
            }

            int i;
            for (i=0;i<3;i++){
                (*patchList)[nFaces].point1[i]=vertexList[d1-1][i];
                (*patchList)[nFaces].point2[i]=vertexList[d2-1][i];
                (*patchList)[nFaces].point3[i]=vertexList[d3-1][i];
            }
            (*patchList)[nFaces].center[0]=1.0/3*((*patchList)[nFaces].point1[0]+(*patchList)[nFaces].point2[0]+(*patchList)[nFaces].point3[0]);
            (*patchList)[nFaces].center[1]=1.0/3*((*patchList)[nFaces].point1[1]+(*patchList)[nFaces].point2[1]+(*patchList)[nFaces].point3[1]);
            (*patchList)[nFaces].center[2]=1.0/3*((*patchList)[nFaces].point1[2]+(*patchList)[nFaces].point2[2]+(*patchList)[nFaces].point3[2]);
            vector_vector_minus((*patchList)[nFaces].point2,(*patchList)[nFaces].point1,AB);
            vector_vector_minus((*patchList)[nFaces].point3,(*patchList)[nFaces].point1,AC);
            cross(AB,AC,tmpN);
            normalize(tmpN,(*patchList)[nFaces].normal);

            nFaces++;
        }
    }

    *finalPatchCount=nFaces;
    fprintf(stderr,"Read %d vertices and %d faces.\n",nVertices,nFaces);


}


int is_visible(int i,int j,patch* patches, int numPatches){
	float direction[3];
	float y0[3];
	vector_vector_minus(patches[i].center,patches[j].center,direction);
	normalize(direction,direction);

	patch* patch1=&(patches[i]);
	patch* patch2=&(patches[j]);

	if(dot(patches[j].normal,direction)<=0.00001 ||dot(patches[i].normal,direction)>=-.000001){
		return 0;
	}

	y0[0]=patch2->center[0]; y0[1]=patch2->center[1]; y0[2]=patch2->center[2];
	float dum1[3];
	float maxTime=(dot(patch1->normal,patch1->point1)-dot(patch1->normal,y0))/(dot(patch1->normal,direction));   
	float N[3];
	patch* patch3;
	float t;
	float intPoint[3];
	int k;
        for (k = 0;k<numPatches;k++){
       		N[0]=patches[k].normal[0];N[1]=patches[k].normal[1]; N[2]=patches[k].normal[2];
        	patch3=&(patches[k]);
 
        	if (dot(N,direction)!=0){
            		t=(dot(N,patch3->point1)-dot(N,y0))/(dot(N,direction));
           		if (t>.000001 && t<maxTime && k!= i && k!=j ){
            		vector_scalar_multiply(direction,t,intPoint);
				    vector_vector_add(intPoint,y0,intPoint);
                	if (point_in_patch(intPoint,patch3->point1,patch3->point2,patch3->point3)){
                		return 0;
			        }
            	}
		}		                
         }
	return 1;
}


void make_vis(patch* patchList, int numPatches, int* visArray){
	int i;
    int (*visibility)[numPatches] = (int (*)[numPatches]) visArray;

#pragma omp parallel for schedule(dynamic, 10)
	for (i=0;i<numPatches;i++){
		visibility[i][i]=0;
		int j;
		for (j=i+1;j<numPatches;j++){
			if (is_visible(i,j,patchList,numPatches)){
				visibility[i][j]=1;
				visibility[j][i]=1;
			}
			else{
				visibility[i][j]=0;
				visibility[j][i]=0;
			}
		}
	}



}


void write_vis(char* outfile,int* visibilityArray, int numPatches){
    int (*visibility)[numPatches] = (int (*)[numPatches]) visibilityArray;
	FILE* fp;
	fp=fopen(outfile,"w");
	if (fp==NULL){
	  fprintf(stderr,"Error opening file %s\n",outfile);
	}
	int i; int j;
	for (i=0;i<numPatches;i++){
		for(j=0; j<numPatches;j++){
			fprintf(fp,"%d ",visibility[i][j]);
		}
		fprintf(fp,"\n");
	}	
}
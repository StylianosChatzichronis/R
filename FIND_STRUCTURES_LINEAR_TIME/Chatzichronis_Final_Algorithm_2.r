#install.packages("bio3d")
#downloading the file with protein ids  in the Home folder
#f=download.file("ftp://ftp.wwpdb.org/pub/pdb/derived_data/index/compound.idx",destfile="idx_file.idx");


#-------------------------------import libraries---------------------------

library("bio3d");

#------------------read from idx file with ids and move data into matrix-----------------------
fileName <- 'idx_file.idx'
fff= readChar(fileName, file.info(fileName)$size);
fff=strsplit(fff, "\n");
l=length(fff[[1]]);
ccc=fff[[1]][5:l];
remove(l);
fff=ccc;
remove(ccc);
fff=strsplit(fff, "\t");
output <- matrix(unlist(fff), ncol = 2, byrow = TRUE);
remove(fff);
remove(fileName);
#remove(f);

#============================ask from user the Query========1N21========5L5V=====2QPS====1U98====1U99=====5NQ3

#Q=readline(prompt = "Give the pdb_id of the query \n");

#-----------------------download from database or load if there is already downloaded----------------
query_id = Q;
Q=read.pdb(Q, maxlines = -1, multi = FALSE, rm.insert = FALSE,rm.alt = TRUE, ATOM.only = FALSE, hex = FALSE, verbose = TRUE);




#***********************************start of algorithm**************************





#=======================computation of Query=======================================
#--------------------we need only Calpha coordinates-----------------------------------------



t = length((which(Q$calpha==TRUE))*3);
cord = rep(NaN,t);
counter=1;

for (i in 1:length(Q$calpha)) {
if(Q$calpha[i]==TRUE){
  cord[counter]   = Q$xyz[[(i-1)*3+1]];
  cord[counter+1] = Q$xyz[[(i-1)*3+2]];
  cord[counter+2] = Q$xyz[[(i-1)*3+3]];
counter=counter+3;
}
}

coordinates_Q = c(xyz=c("xyz"),size=0,name=query_id);
coordinates_Q$xyz = cord;
coordinates_Q$size = length((which(Q$calpha==TRUE)))*3;


#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-finding centroids G_right, G_left-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

half_v = length(coordinates_Q$xyz)-(length(coordinates_Q$xyz))%%2;
half_v = (half_v - half_v%%3)/2;
t_square_left =  sqrt((half_v/3)/(coordinates_Q$size/3));
t_square_right=  sqrt(((coordinates_Q$size/3)-half_v/3)/(coordinates_Q$size/3));

sumx = 0;
sumy = 0;
sumz = 0;
i=1;
while(i<half_v) {
sumx = sumx + coordinates_Q$xyz[i];
sumy = sumy + coordinates_Q$xyz[i+1];
sumz = sumz + coordinates_Q$xyz[i+2];
i=i+3;
}
G_right_Q = c(sumx,sumy,sumz) /half_v;

sumx = 0;
sumy = 0;
sumz = 0;
i=half_v+1;
while(i<length(coordinates_Q$xyz)) {
sumx = sumx + coordinates_Q$xyz[i];
sumy = sumy + coordinates_Q$xyz[i+1];
sumz = sumz + coordinates_Q$xyz[i+2];
i=i+3;
}
G_left_Q = c(sumx,sumy,sumz) /(length(coordinates_Q$xyz)-half_v);






#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-finding centroids G_right, G_left-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=






#=============================read ids from matrix, download pdb files==========



#==============iteration over packets===============================

counter_iter=1;
counter1=1;
packet=100;
total_time=0;
iter=length(output)-(length(output)%%packet);
number_of_proteins =0;
number_of_substructures=0;
rmsd_var = list(value=-1,name="NaN",start=-1);
while(counter1<=(iter+1)){








ids = unlist(output[((counter1-1)*100+1):(counter1*packet),1], recursive = TRUE, use.names = TRUE);
ids = as.character(ids);


#-------------create a list of pdb files----------------------------
pdb_list=NULL;
coordinates_P=NULL;
pdb_length <- rep(0,length(ids));
pdb_file=1;

coordinates_P = c(xyz=c("NaN"),size=0);
cord = rep(NaN,1);
#cord = c(xyz=NaN,calpha=-1);
coordinates_P$xyz = cord;
coordinates_P$name = "NaN";



#--------------store coordinates of Calpha and length of each molecule---------------
for (i in 1:(length(ids))) {
	pdb_file=try(read.pdb(ids[i],maxlines=-1,multi=FALSE,rm.insert=FALSE,rm.alt=TRUE,ATOM.only=FALSE,hex=FALSE,verbose=TRUE));


	if(typeof(pdb_file)!="character"){
		Calpha = which(pdb_file$calpha==TRUE);
		t = length((which(pdb_file$calpha==TRUE)))*3;
		cord = rep(NaN,1);
		counter=1;
		tr=length(which(Q$calpha==TRUE))*3;	
		#------------if there is Calpha or protein is greater than the query--------------
		if( t >=tr){
			for (j in 1:(length(pdb_file$calpha))) {
				if(pdb_file$calpha[j]==TRUE){
					cord[counter]   = pdb_file$xyz[[(j-1)*3+1]];
					cord[counter+1] = pdb_file$xyz[[(j-1)*3+2]];
					cord[counter+2] = pdb_file$xyz[[(j-1)*3+3]];
					counter=counter+3;
				}
			}
				coordinates_P$xyz = c(coordinates_P$xyz,cord);
				coordinates_P$size = c(coordinates_P$size,length(cord));
				coordinates_P$name = c(coordinates_P$name,ids[i])
		}else{
		#-remove from list------
		ids = ids[(which(ids!=ids[i]))]; 
		}
	}else{
	#----------------if pdb doesn't exist remove from list----------------------
	print(ids[i]); print("doesn't exist or cannot be read properly due to C++ error remove from list");
	  #ids = ids[(which(ids!=ids[i]))]; 
	}
}#--------------------end of for--------------


coordinates_P$size = coordinates_P$size[which(coordinates_P$size!="NaN")];
coordinates_P$xyz = coordinates_P$xyz[which(coordinates_P$xyz!="NaN")];
coordinates_P$name = coordinates_P$name[which(coordinates_P$name!="NaN")];

#---------------remove false data------------------------------
if(length((which(coordinates_P$size!=0)))){
ids = ids[(which(coordinates_P$size!=0))]; 
coordinates_P$size = coordinates_P$size[(which(coordinates_P$size!=0))]; 

}

coordinates_P$size = strtoi(coordinates_P$size);




b = -1;

hits=0;
D_values = -1;
#=======================calculating from 100 substructures of P=======================================
number_of_proteins = number_of_proteins+length(coordinates_P$size);
number_of_substructures = number_of_substructures + sum(coordinates_P$size)/3-sum(coordinates_Q$size)/3+length(coordinates_P$size);
start_time <- Sys.time();
counter3=1;
counter4=0;
for (i in 1:(length(coordinates_P$size))) {
	start=TRUE;
	j=1;
	while(j<=(coordinates_P$size[i]-(length(coordinates_Q$xyz))+1)) {

	if(start==TRUE){

		#finding centroids G_right, G_left
		
		half_v = length(coordinates_Q$xyz)-(length(coordinates_Q$xyz))%%2;
		half_v = (half_v - half_v%%3)/2;

		sumx = 0;
		sumy = 0;
		sumz = 0;
		e=1;
		while(e<=half_v) {
			sumx = sumx + coordinates_P$xyz[e+(counter4+j)-1];
			sumy = sumy + coordinates_P$xyz[e+(counter4+j)+1-1];
			sumz = sumz + coordinates_P$xyz[e+(counter4+j)+2-1];
			e=e+3;
		}
		G_right_P = c(sumx,sumy,sumz) /half_v;

		sumx = 0;
		sumy = 0;
		sumz = 0;
		e=half_v+1;
		while(e<=length(coordinates_Q$xyz)) {
			sumx = sumx + coordinates_P$xyz[e+(counter4+j)-1];
			sumy = sumy + coordinates_P$xyz[e+(counter4+j)+1-1];
			sumz = sumz + coordinates_P$xyz[e+(counter4+j)+2-1];
			e=e+3;
		}
		G_left_P = c(sumx,sumy,sumz) /(length(coordinates_Q$xyz)-half_v);

		start=FALSE;
	}else{
		#finding centroids G_right, G_left

		tt= length(coordinates_Q$xyz) - (length(coordinates_Q$xyz))%%2;
		tt = tt/2;
		G_left_P = G_left_P - (1/tt)*( c(coordinates_P$xyz[(counter4+j)],coordinates_P$xyz[(counter4+j)+1],coordinates_P$xyz[(counter4+j)+2])  );
		G_right_P = G_right_P - (1/tt)*(c(coordinates_P$xyz[tt+(counter4+j)],coordinates_P$xyz[tt+(counter4+j)+1],coordinates_P$xyz[tt+(counter4+j)+2]));
	}



#----------------------compute F for even or odd n---------------------------------
	  
	  
	  
	  if((length(coordinates_Q$xyz)/3)%%2==0 ){
	    
	    F_left =  t_square_left*sqrt((G_left_P[1]-G_left_Q[1])^2+ (G_left_Q[2]-G_left_P[2])^2+(G_left_Q[3]-G_left_P[3])^2 )/1;
	  }else{
	    F_left = t_square_left*(sqrt(   (((coordinates_Q$size/3)/2)-1)/((coordinates_Q$size/3)/2)  ))*(sqrt((G_left_P[1]-G_left_Q[1])^2+ (G_left_Q[2]-G_left_P[2])^2+(G_left_Q[3]-G_left_P[3])^2 )/1);
	  }
	  
	  if((length(Q$xyz)/3)%%2==0 ){
		F_right = t_square_right*sqrt((G_right_Q[1]-G_right_P[1])^2+ (G_right_Q[2]-G_right_P[2])^2+(G_right_Q[3]-G_right_P[3])^2 )/2;
	}else{
		F_right = t_square_right*(sqrt(   ((((coordinates_Q$size/3))/2)-1)/((coordinates_Q$size/3)/2)  ))*(sqrt((G_right_Q[1]-G_right_P[1])^2+ (G_right_Q[2]-G_right_P[2])^2+(G_right_Q[3]-G_right_P[3])^2 )/2);
	}


#----------------------compute D---------------------------
	D_left = abs(F_left) ;	
	D_right = abs(F_right);	
	D = (D_left^2 + D_right^2)^0.5
	if(D<1){
	  hits = hits+1;
	  r =rmsd(coordinates_Q$xyz,coordinates_P$xyz[(counter4+j):(length(coordinates_Q$xyz)+(counter4+j) -1)]);
	  if(r<1){
	    
	#rmsd_var = c(rmsd_var$value,r);
	rmsd_var$value = c(rmsd_var$value,r);
	rmsd_var$name = c(rmsd_var$name,coordinates_P$name[i]);
	rmsd_var$start = c(rmsd_var$start,j);
	
	}
	}
	
	
	
	
	counter_iter = counter_iter +1;
	counter3=counter3+1;
	j=j+3;
	
	
}#end of whilej
	
	counter4=counter4+coordinates_P$size[i];
	
}#end of fori




end_time <- Sys.time();
time_is=end_time-start_time;
total_time = total_time+time_is;

if(iter!=counter1){
  counter1 = counter1 +1;
}else{
  packet = length(output)%%packet;
}


}#-----------end of while iter----------


#------------after algorithm processing-----------------

#-----remove initialized values NaN-------------
rmsd_var[[1]] = rmsd_var[[1]][2:length(rmsd_var[[1]])];
rmsd_var[[2]] = rmsd_var[[2]][2:length(rmsd_var[[2]])];
rmsd_var[[3]] = rmsd_var[[3]][2:length(rmsd_var[[3]])];

b=b[2:length(b)];



#--------------------use plot3D---library---------------
library("plot3D");




pdf('results_2.pdf')
i=1;
x = rep(NaN,(coordinates_Q$size/3));
y = rep(NaN,(coordinates_Q$size/3));
z = rep(NaN,(coordinates_Q$size/3));
while(i<coordinates_Q$size) {
  x[((i-1))/3+1]=coordinates_Q$xyz[i];
  y[((i-1))/3+1]=coordinates_Q$xyz[i+1];
  z[((i-1))/3+1]=coordinates_Q$xyz[i+2];
i=i+3;
}

scatter3D(x,y,z,type="l",main=coordinates_Q$name,pch=20)
points3D(x,y,z,type="b",main=coordinates_Q$name, pch=20)
points3D(x,y,z,type="p",main=coordinates_Q$name,pch=19)
points3D(x,y,z,type="l",main=coordinates_Q$name,pch=20)

scatter3D(x,y,z,type="b",main="0 degrees",theta = 0,pch=20)
scatter3D(x,y,z,type="b",main="60 degrees",theta = 60,pch=20)
scatter3D(x,y,z,type="b",main="180 degrees",theta = 120,pch=20)
scatter3D(x,y,z,type="b",main="180 degrees",theta = 180,pch=20)
scatter3D(x,y,z,type="b",main="240 degrees",theta = 240,pch=20)
scatter3D(x,y,z,type="b",main="300 degrees",theta = 300,pch=20)

scatter3D(x,y,z,type="l",main="0 degrees",theta = 0,pch=20)
scatter3D(x,y,z,type="l",main="60 degrees",theta = 60,pch=20)
scatter3D(x,y,z,type="l",main="180 degrees",theta = 120,pch=20)
scatter3D(x,y,z,type="l",main="180 degrees",theta = 180,pch=20)
scatter3D(x,y,z,type="l",main="240 degrees",theta = 240,pch=20)
scatter3D(x,y,z,type="l",main="300 degrees",theta = 300,pch=20)




i=1;
links=NULL;
while(i<=length(rmsd_var$name)) {
  
links=c(links,paste("https://files.rcsb.org/download/",rmsd_var$name[i],sep=""));
i=i+1;
}
barplot(rmsd_var$value,names.arg =rmsd_var$name,col="dark blue",ylab = "rmsd",y=c(0,max(rmsd_var$value)+1))
barplot(rmsd_var$value,names.arg =links,col="dark blue",ylab = "rmsd",y=c(0,max(rmsd_var$value)+1))
dev.off();


#-------------------end-------------------------









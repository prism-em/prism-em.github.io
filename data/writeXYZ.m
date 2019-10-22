<<<<<<< HEAD
function [] = writeXYZ(fileName,comment,...
    cellDim,IDarray,xyzArray,occArray,uArray)

% Write .xyz file for Prismatic

if length(IDarray) == 1
    IDarray = IDarray*ones(size(xyzArray,1),1);
end
if length(occArray) == 1
    occArray = occArray*ones(size(xyzArray,1),1);
end
if length(uArray) == 1
    uArray = uArray*ones(size(xyzArray,1),1);
end

% Initialize file
fid = fopen(fileName,'w');

% Write comment line (1st)
fprintf(fid,[comment '\n']);

% Write cell dimensions
fprintf(fid,'    %f %f %f\n',cellDim(1:3));

% Write atomic data
dataAll = [IDarray xyzArray occArray uArray];
for a0 = 1:size(dataAll,1)
    fprintf(fid,'%d  %f  %f  %f  %d  %f\n',dataAll(a0,:));
end

% Write end of file, for computem compatibility
fprintf(fid,'-1\n');

% Close file
fclose(fid);


=======
function [] = writeXYZ(fileName,comment,...
    cellDim,IDarray,xyzArray,occArray,uArray)

% Write .xyz file for Prismatic

if length(IDarray) == 1
    IDarray = IDarray*ones(size(xyzArray,1),1);
end
if length(occArray) == 1
    occArray = occArray*ones(size(xyzArray,1),1);
end
if length(uArray) == 1
    uArray = uArray*ones(size(xyzArray,1),1);
end

% Initialize file
fid = fopen(fileName,'w');

% Write comment line (1st)
fprintf(fid,[comment '\n']);

% Write cell dimensions
fprintf(fid,'    %f %f %f\n',cellDim(1:3));

% Write atomic data
dataAll = [IDarray xyzArray occArray uArray];
for a0 = 1:size(dataAll,1)
    fprintf(fid,'%d  %f  %f  %f  %d  %f\n',dataAll(a0,:));
end

% Write end of file, for computem compatibility
fprintf(fid,'-1\n');

% Close file
fclose(fid);


>>>>>>> 1d203415e6547b8ddf9922ebc9e87d50d0045e36
end
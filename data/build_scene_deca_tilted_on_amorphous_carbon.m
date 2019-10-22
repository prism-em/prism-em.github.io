function [atoms,cellDim,Irgb] = ...
    build_scene_deca_tilted_on_amorphous_carbon(xyzSub,xyzNP)

% Input variables
% xyzSub                    % (x,y,z) coordinates of substrate in A
% xyzNP                     % (x,y,z) coordinates of nanoparticle in A
dr = 0.1;
sigma = 2;
shiftNP = [50 50 60.2];     % nanoparticle (x,y,z)
rMin = 3;                   % minimum atomic separation
theta = [0 -30 0]*pi/180;   % three angles for ZXZ rotation
ID_NP = 78;                 % atomic number of NP
ID_Sub = 6;                 % atomic number of the substrate
cellSub = [50 50 50];       % Substrate cell size


% Tile 2x2 in xy, permuting dimensions to avoid tiling artifacts
atomsSub = [ ...
    xyzSub(:,[1 2 3])+repmat([0 0 0],[size(xyzSub,1) 1]);
    xyzSub(:,[2 1 3])+repmat([cellSub(1) 0 0],[size(xyzSub,1) 1]);
    xyzSub(:,[3 1 2])+repmat([0 cellSub(2) 0],[size(xyzSub,1) 1]);
    xyzSub(:,[2 1 3])+repmat([cellSub(1:2) 0],[size(xyzSub,1) 1]);
    ];
cellDim = [2*cellSub(1:2) cellSub(3)];

% nanoparticle (NP)
xyzNP = xyzNP(:,1:3);
for a0 = 1:3
    xyzNP(:,a0) = xyzNP(:,a0) - mean(xyzNP(:,a0));
end
% Rotate and translate NP
m = [cos(theta(1)) -sin(theta(1)) 0;
    sin(theta(1)) cos(theta(1)) 0;
    0 0 1];
xyzNP = (m'*xyzNP')';
m = [1 0 0;
    0 cos(theta(2)) -sin(theta(2));
    0 sin(theta(2)) cos(theta(2))];
xyzNP = (m'*xyzNP')';
m = [cos(theta(3)) -sin(theta(3)) 0;
    sin(theta(3)) cos(theta(3)) 0;
    0 0 1];
xyzNP = (m'*xyzNP')';
for a0 = 1:3
    xyzNP(:,a0) = xyzNP(:,a0) + shiftNP(a0);
end

% Make plots
Nxy = cellDim(1:2)/dr;
xInd = mod(round(atomsSub(:,1)/dr),Nxy(1))+1;
yInd = mod(round(atomsSub(:,2)/dr),Nxy(2))+1;
potSub = accumarray([xInd yInd],ones(size(atomsSub,1),1),Nxy);
% smoothing
k = fspecial('gaussian',2*ceil(3*sigma)+1,sigma);
potSub = convolve2(potSub,k,'wrap');
potSub = potSub - min(potSub(:));
potSub = potSub / max(potSub(:));
% Np
xInd = mod(round(xyzNP(:,1)/dr),Nxy(1))+1;
yInd = mod(round(xyzNP(:,2)/dr),Nxy(2))+1;
potNP = accumarray([xInd yInd],ones(size(xyzNP,1),1),Nxy);
potNP = convolve2(potNP,k,'wrap');
potNP = sqrt(potNP);
% potNP = sqrt(potNP);
potNP = potNP - min(potNP(:));
potNP = potNP / max(potNP(:));

% RGB output image
Irgb = zeros(Nxy(1),Nxy(2),3);
Irgb(:,:,1) = potNP;
Irgb(:,:,2) = potSub/2;
Irgb(:,:,3) = potSub/2;

figure(1)
clf
imagesc(Irgb)
axis equal off
colormap(gray(256))
set(gca,'position',[0 0 1 1])

% Delete substrate atoms
del = false(size(atomsSub,1),1);
r2 = rMin^2;
for a0 = 1:size(atomsSub,1)
    if (    min((atomsSub(a0,1)-xyzNP(:,1)).^2 ...
            + (atomsSub(a0,2)-xyzNP(:,2)).^2 ...
            + (atomsSub(a0,3)-xyzNP(:,3)).^2) < r2)
        del(a0)=  true;
    end
end
atomsSub(del,:) = [];

% Combine atoms
atoms = [[atomsSub ones(size(atomsSub,1),1)*ID_Sub];
    [xyzNP ones(size(xyzNP,1),1)*ID_NP]];

% scatter plot
figure(2)
clf
v = (1:size(atoms,1))';
hold on
s = mod(v,1) == 0 & atoms(:,4) == ID_NP;
scatter3(atoms(s,1),atoms(s,2),atoms(s,3),'r.')
s = mod(v,10) == 0 & atoms(:,4) == ID_Sub;
scatter3(atoms(s,1),atoms(s,2),atoms(s,3),'g.')
hold off
axis equal
view([1 0 0])
box on



cellDim(3) = ceil(max(atoms(:,3))/2)*2;
for a0 = 1:3
    atoms(:,a0) = atoms(:,a0) / cellDim(a0);
end
end
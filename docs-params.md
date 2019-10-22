---
title: Input Parameters
subtitle: Description of Prismatic input parameters.
---


<a name ="cli-options"></a>
## Using `Prismatic` from the command line

`Prismatic` contains a command line tool, `prismatic`, that can be used to run simulations from within a terminal, bash script, etc. Building it requires the `CMake` variable `PRISM_ENABLE_CLI=1` at compilation time, which is the default behavior.

The following options are available with `prismatic` (you can also print available options and default values with `prismatic --help`), each documented as **_long form_** **_(short form)_** *parameters* : description

Basic usage is prismatic -i filename [other options]:

* --input-file (-i) filename :  filename containing the atomic coordinates, see www.prism-em.com/about for details (default: /path/to/atoms.txt)
* --param-file (-pf) filename : filename containing simulation parameters. This optional file can contain any number of parameters in the form of a text file with one entry per line of the form param:value.
* --output-file(-o) filename : output filename (default: output.h5)
* --interp-factor (-f) number : PRISM interpolation factor, used for both X and Y (default: 4)
* --interp-factor-x (-fx) number : PRISM interpolation factor in X (default: 4)
* --interp-factor-y (-fy) number : PRISM interpolation factor in Y (default: 4)
* --num-threads (-j) value : number of CPU threads to use (default: 12)
* --num-streams (-S) value : number of CUDA streams to create per GPU (default: 3)
* --num-gpus (-g) value : number of GPUs to use. A runtime check is performed to check how many are actually available, and the minimum of these two numbers is used. (default: 4)
* --slice-thickness (-s) thickness : thickness of each slice of projected potential (in Angstroms) (default: 2)
* --num-slices (-ns) number of slices: in multislice mode, number of slices before intermediate output is given (default: 0)
* --zstart-slices (-zs) value: in multislice mode, depth Z at which to begin intermediate output (default: 0)
* --batch-size (-b) value : number of probes/beams to propagate simultaneously for both CPU and GPU workers. (default: 1)
* --batch-size-cpu (-bc) value : number of probes/beams to propagate simultaneously for CPU workers. (default: 1)
* --batch-size-gpu (-bg) value : number of probes/beams to propagate simultaneously for GPU workers. (default: 1)
* --help(-h) : print information about the available options
* --pixel-size (-p) pixel_size : size of simulated potential/probe X/Y pixel size (default: 0.1). Note this is different from the size of a pixel in the output, which is determined by probe_stepX(Y)
* --pixel-size-x (-px) pixel_size : size of simulated potential/probe X pixel size (default: 0.1). Note this is different from the size of a pixel in the output, which is determined by probe_stepX(Y)
* --pixel-size-y (-py) pixel_size : size of simulated potential/probe Y pixel size (default: 0.1). Note this is different from the size of a pixel in the output, which is determined by probe_stepX(Y)
* --detector-angle-step (-d) step_size : angular step size for detector integration bins (in mrad) (default: 1)
* --cell-dimension (-c) x y z : size of sample in x, y, z directions (in Angstroms) (default: 20 20 20)
* --tile-uc (-t) x y z : tile the unit cell x, y, z number of times in x, y, z directions, respectively (default: 1 1 1)
* --algorithm (-a) p/m : the simulation algorithm to use, either (p)rism or (m)ultislice (default: PRISM)
* --energy (-E) value : the energy of the electron beam (in keV) (default: 80)
* --alpha-max (-A) angle : the maximum probe angle to consider (in mrad) (default: 24)
* --potential-bound (-P) value : the maximum radius from the center of each atom to compute the potental (in Angstroms) (default: 2)
* --also-do-cpu-work (-C) bool=true : boolean value used to determine whether or not to also create CPU workers in addition to GPU ones (default: 1)
* --streaming-mode 0/1 : boolean value to force code to use (true) or not use (false) streaming versions of GPU codes. The default behavior is to estimate the needed memory from input parameters and choose automatically. (default: Auto)
* --probe-step (-r) step_size : step size of the probe for both X and Y directions (in Angstroms) (default: 0.25)
* --probe-step-x (-rx) step_size : step size of the probe in X direction (in Angstroms) (default: 0.25)
* --probe-step-y (-ry) step_size : step size of the probe in Y direction (in Angstroms) (default: 0.25)
* --random-seed (-rs) step_size : random integer number seed
* --probe-xtilt (-tx) value : probe X tilt (in mrad) (default: 0)
* --probe-ytilt (-ty) value : probe X tilt (in mrad) (default: 0)
* --probe-defocus (-df) value : probe defocus (in Å) (default: 0)
* -C3 value : microscope C3 aberration constant (in Angstrom) (default: 0)
* -C5 value : microscope C5 aberration constant (in Angstrom) (default: 0)
* --probe-semiangle (-sa) value : maximum probe semiangle (in mrad) (default: 20)
* --scan-window-x (-wx) min max : size of the window to scan the probe in X (in fractional coordinates between 0 and 1) (default: 0 0.99999)
* --scan-window-y (-wy) min max : size of the window to scan the probe in Y (in fractional coordinates between 0 and 1) (default: 0 0.99999)
* --scan-window-xr (-wxr) min max : size of the window to scan the probe in X (in Angstroms) (defaults to fractional coordinates) )
* --scan-window-yr (-wyr) min max : size of the window to scan the probe in Y (in Angstroms) (defaults to fractional coordiantes) )
* --num-FP (-F) value : number of frozen phonon configurations to calculate (default: 1)
* --thermal-effects (-te) bool : whether or not to include Debye-Waller factors (thermal effects) (default: True)
* --occupancy (-oc) bool : whether or not to consider occupancy values for likelihood of atoms existing at each site (default: True)
* --save-2D-output (-2D) ang_min ang_max : save the 2D STEM image integrated between ang_min and ang_max (in mrads) (default: Off)
* --save-3D-output (-3D) bool=true : Also save the 3D output at the detector for each probe (3D output mode) (default: On)
* --save-4D-output (-4D) bool=false : Also save the 4D output at the detector for each probe (4D output mode) (default: Off)
* --save-DPC-CoM (-DPC) bool=false : Also save the DPC Center of Mass calculation (default: Off)
* --save-real-space-coords (-rsc) bool=false : Also save the real space coordinates of the probe dimensions (default: Off)
* --save-potential-slices (-ps) bool=false : Also save the calculated potential slices (default: Off)
* --nyquist-sampling (-nqs) bool=false : Set number of probe positions at Nyquist sampling limit (default: Off)]


<a name ="parameter-file"></a> 

## Parameter File

Input parameters may also be provided in the form a plain-text parameter file with one line per option of the form "option:args" without quotes. Any number of arguments can be provided, and if repeat values exist the most recent one will be effectively applied. These options are the same CLI options described in the previous section. This is useful for sharing simulation parameters with collaborators as an .XYZ file with associated parameter file uniquely determines a simulation. A parameter file is also written by default every time `prismatic` is run or a simulation is run within the GUI. For the GUI, this parameter file is loaded at startup and thus populates the GUI with the previous simulation parameters for convenience. The "Load Parameters" buttons may be used to populate the GUI from an existing file and the current parameters may be output to a custom file with "Save Parameters".

<a name="pyprismatic-metadata"></a>
## List of `PyPrismatic` Metadata parameters


**interpolationFactorX** : PRISM interpolation factor in x-direction  
**interpolationFactorY** : PRISM interpolation factor in y-direction  
**filenameAtoms** : filename containing input atom information in XYZ format (see [here](http://prism-em.com/about/) for more details)  
**filenameOutput** : filename in which to save the 3D output. Also serves as base filename for 2D and 4D outputs if used  
**realspacePixelSizeX** : size of pixel size in X for probe/potential arrays  
**realspacePixelSizeY** : size of pixel size in Y for probe/potential arrays  
**potBound** : limiting radius within which to compute projected potentials from the center of each atom (in Angstroms)  
**numFP** : number of frozen phonon configurations to average over  
**sliceThickness** : thickness of potential slices (in Angstroms)  
**numSlices** : number of slices between intermediate outputs
**zStart**: depth before intermediate output begins (in Angstroms)
**cellDimX** : unit cell dimension X (in Angstroms)  
**cellDimY** : unit cell dimension Y (in Angstroms)  
**cellDimZ** : unit cell dimension Z (in Angstroms)  
**tileX** : number of unit cells to tile in X direction  
**tileY** : number of unit cells to tile in Y direction  
**tileZ** : number of unit cells to tile in Z direction  
**E0** : electron beam energy (in eV)  
**alphaBeamMax** : the maximum probe angle to consider (in mrad)  
**numGPUs** : number of GPUs to use. A runtime check is performed to check how many are actually available, and the minimum of these two numbers is used   
**numStreamsPerGPU** : number of CUDA streams to use per GPU  
**numThreads** : number of CPU worker threads to use  
**batchSizeTargetCPU** : desired batch size for CPU FFTs  
**batchSizeTargetGPU** : desired batch size for GPU FFTs  
**earlyCPUStopCount** : the WorkDispatcher will cease providing work to CPU workers earlyCPUStopCount jobs from the end. This is to prevent the program waiting for slower CPU workers to complete  
**probeStepX** : step size of the probe in X direction (in Angstroms)  
**probeStepY** : step size of the probe in Y direction (in Angstroms)  
**probeDefocus** : probe defocus (in Angstroms)  
**C3** : microscope C3 (in Angstroms)    
**probeSemiangle** : probe convergence semi-angle (in mrad)  
**detectorAngleStep** : angular step size for detector integration bins (in mrad)  
**probeXtilt** : probe X tilt (in mrad)  
**probeYtilt** : probe X tilt (in mrad)  
**scanWindowXMin** : lower X size of the window to scan the probe (in fractional coordinates)  
**scanWindowXMax** : upper X size of the window to scan the probe (in fractional coordinates)  
**scanWindowYMin** : lower Y size of the window to scan the probe (in fractional coordinates)  
**scanWindowYMax** : upper Y size of the window to scan the probe (in fractional coordinates) 
**scanWindowXMin_r**: lower X size of the window to scan the probe (in Angstroms)
**scanWindowYMin_r** : lower Y size of the window to scan the probe (in Angstroms)
**scanWindowXMax_r**: upper X size of the window to scan the probe (in Angstroms)
**scanWindowYMax_r** : upper Y size of the window to scan the probe (in Angstroms)
**randomSeed** : number to use for random seeding of thermal effects  
**algorithm** : simulation algorithm to use, "prism" or "multislice"  
**includeThermalEffects** : true/false to apply random thermal displacements (Debye-Waller effect)  
**alsoDoCPUWork** : true/false to spawn CPU workers in addition to GPU workers  
**save2DOutput** : save the 2D STEM image integrated between integrationAngleMin and integrationAngleMax  
**save3DOutput** : true/false Also save the 3D output at the detector for each probe (3D output mode)  
**save4DOutput** : true/false Also save the 4D output at the detector for each probe (4D output mode)  
**:saveDPC_CoM** : true/false Also save the DPC center of mass calculation for each probe
**:savePotentialSlices**  : true/false Also save the projected potential array
**:nyquistSampling** : set number of probe positions at Nyquist sampling limit
**integrationAngleMin** : inner detector position (for 2D output mode) (in mrad)  
**integrationAngleMax** : outer detector position (for 2D output mode) (in mrad)  
**transferMode** : memory model to use, either "streaming", "singlexfer", or "auto"  

---
title: SuperSTEM 2018 GUI Tutorial
subtitle: Performing Prismatic simulations using the GUI
---


![Prismatic screenshot 01](img/SuperSTEMtopbar.png){:width="1184px"}

*Tutorial by Colin Ophus (clophus 'at' lbl.gov)*

*Note that this tutorial was designed for `Prismatic`  version 1.1 - however it should be fully compatible with the current version.*



## Table of Contents  
- [1 - Install `Prismatic`](#step1)
- [2 - Load atomic coordinates](#step2)
- [3 - Set microscope parameters](#step3)
- [4 - Projected atomic potentials](#step4)
- [5 - Unit cell tiling](#step5)
- [6 - `PRISM` accuracy](#step6)
- [7 - Run simulations](#step7)
- [8 - Save results](#step8)
- [9 - Further simulations](#step9)



<a name="step1"></a>
&nbsp;

## 1 - Download and Install the `Prismatic` GUI.

The `Prismatic` GUI has been compiled for both Windows and OSX. For each of these operating systems, there are two possible versions of Prismatic you may wish to install.

### For Windows:

If your computer has an NVIDIA GPU that can run CUDA code, install:
[Prismatic-GPU-v1.1.msi](https://drive.google.com/open?id=1B9Yq-BBWY3VvNRD-aiKTWGzDME7s8qPh)

Otherwise, install:
[Prismatic-v1.1.msi](https://drive.google.com/open?id=13TZZc1ZAzMMx-cmfiCJCL4pBPqW_icWS)

### For OSX:

If you are running OSX 10.13.1 (High Sierra), install:
[Prismatic-OSX-v1.1.dmg (High Sierra)](https://drive.google.com/open?id=1OnclVmfDv9oIAXVdTbq6dp94DDiLuWfk)

If you are running OSX 10.12.6 (Sierra), install:
[Prismatic-OSX-v1.1.dmg (Sierra)](https://drive.google.com/open?id=1S1utdTErovvkf-o5P4gTRB5IeC4smYqZ)

The GPU portions of `Prismatic` were developed using CUDA. This means that Apple laptops and Mac desktops running AMD GPUs cannot make use of CUDA GPU code. However, the PRISM algorithm is quite fast. Therefore you may be able to run STEM simulations on Apple laptops in reasonable times. After downloading and installing `Prismatic`, run it to verify the installation has succeeded. At this stage, we will discuss the best settings for the number of GPU and CPU threads to use for best results in `Prismatic`.



<a name="step2"></a>
&nbsp;
## 2 - Download coordinates, load into `Prismatic`.


The sample we are going to examine in this tutorial is barium neodymium titanate. This material has a complex unit cell, with the tungsten bronze parent structure. From this unit cell, we have constructed 5 different zone axes by projecting the unit cell into new pseudo-orthogonal unit cells. This methodology is described below.

`Prismatic` uses the same .xyz file format as Kirkland's computem software. We also assume the beam propagation direction is along the z axis. This file format contains 2 header lines, a comment and the cell dimensions (along x, y and z respectively). Next, the atom coordinates are listed in rows with these 6 column values:

1. atomic number
2. x 
3. y 
4. z 
5. occupancy 
6. RMS thermal vibration

Occupancy currently is assumed to be 1 for all atomic sites. The x, y, z, and RMS thermal vibration magnitude (root-mean-square atomic displacement) are all in units of Angstroms. Typical values for the RMS thermal displacements are 0.05 to 0.1 Angstroms.

For this tutorial, please download these five .xyz files:

[Barium Neodymium Titanate - [0 1 0] zone axis](/data/SuperSTEM/barium_neodymium_titanate_0_1_0.xyz)

[Barium Neodymium Titanate - [0 2 1] zone axis](/data/SuperSTEM/barium_neodymium_titanate_0_2_1.xyz)

[Barium Neodymium Titanate - [0 1 1] zone axis](/data/SuperSTEM/barium_neodymium_titanate_0_1_1.xyz)

[Barium Neodymium Titanate - [0 1 2] zone axis](/data/SuperSTEM/barium_neodymium_titanate_0_1_2.xyz)

[Barium Neodymium Titanate - [0 0 1] zone axis](/data/SuperSTEM/barium_neodymium_titanate_0_0_1.xyz)

After downloading these files, load the first file ([0 1 0] zone axis) into `Prismatic` using the **Load Coords** button. The below screenshot shows what you should see after loading this file, specifically the unit cell dimensions along x, y and z:

![SuperSTEM screenshot 01](img/SuperSTEM/screenshot01.png){:width="960"}

You should see x, y and z cell dimensions of 22.3, 12.2, and 7.7 Angstroms respectively.









<a name="step3"></a>
&nbsp;
## 3 - Microscope parameters and simulation settings.

In the following sections, I have highlighted each `Prismatic` setting using <span style="color:red">**bold red text**</span>. This is to ensure that you can easily find the parameters used in this tutorial.

### Sample Settings:

Besides loading and saving, this settings box shows the cell dimensions and allows us to tile the unit cell along the three primary dimensions. Initially, we are going to skip over the **Tile Cells** settings, because they require very careful analysis to set correctly.

### Simulation Settings Block 1:

The first two buttons, **Load Parameters** and **Save Parameters** can save and load text files containing `Prismatic` settings. These files can be used in the GUI or command line versions of `Prismatic` and thus are very useful when submitting batch simulations.

The first setting, **Pixel Size**, is extremely important because it controls the high angle scattering accuracy of the simulation. This is because the pixel size <img src="https://latex.codecogs.com/svg.latex?\Large&space;p"/>
 in real space defines the maximum inverse spatial coordinate value in Fourier space <img src="https://latex.codecogs.com/svg.latex?\Large&space;q_{max}"/>, using the formula:

<img src="https://latex.codecogs.com/svg.latex?\Large&space;q_{max}=\frac{1}{2 p}"/>

`Prismatic` also includes a mathematical function to prevent an artifact called "aliasing" from occurring, which happens because of the periodicity assumption of the discrete Fourier transform. `Prismatic` uses an "anti-aliasing" aperture at 0.5 times the maximum scattering angle, which further reduces the maximum effective scattering angle by a factor of 0.5. This fact combined with the above equation and the formula 
<img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha = \lambda q "/> gives the maximum scattering angle <img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha_{max}"/> equation


<img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha_{max} = \frac{\lambda}{4 p}"/>

where <img src="https://latex.codecogs.com/svg.latex?\Large&space;\lambda "/>  is the relativistic electron wavelength. As an example, consider a case where we want to simulate 300 kV electron scattering angles up to 100 mrads. At 300 kV, <img src="https://latex.codecogs.com/svg.latex?\Large&space;\lambda \approx "/> 0.02 Angstroms. Plugging these values into the above equation gives

<img src="https://latex.codecogs.com/svg.latex?\Large&space;p = \frac{\lambda}{4 \alpha_{max}} = \frac{0.02}{(4)(0.1)} = 0.05"/>

i.e. we require a 0.05 Angstrom pixel size <img src="https://latex.codecogs.com/svg.latex?\Large&space;p"/> in order to reach a maximum scattering angle <img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha_{max}"/> of 100 mrads.



For this tutorial, we will use a **Pixel Size** value of <span style="color:red">**0.1 Angstroms**</span> in order to save time, and we will set the accelerating voltage (in kV) using the **Energy** box to <span style="color:red">**100 kV**</span>. Note that including these settings will immediately update the wavelength <img src="https://latex.codecogs.com/svg.latex?\Large&space;\lambda"/> and maximum scattering angle <img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha_{max}"/> displayed values to

<img src="https://latex.codecogs.com/svg.latex?\Large&space;\lambda = "/> 0.037 Angstroms

<img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha_{max} = "/> 92.5 mrads

The next value  **Potential Bound** specifies how far from the atomic core we will integrate the projected potentials. Set this value to <span style="color:red">**2 Angstroms**</span> for reasonable accuracy.




### Simulation Settings Block 2:

The next set of parameters describe the values required to describe the incident converged electron probe. The semiangle of the probe specified by a condenser aperture is given by the **Probe Semiangle** box, which you should set to <span style="color:red">**30 mrads**</span>. For the `PRISM` algorithm we also need to specify the **Probe <img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha"/> limit**, which corresponds to the maximum scattering angle computed for the Compact S-Matrix. This value should be set slightly larger than the **Probe Semiangle**, so we will use a value of <span style="color:red">**32 mrads**</span> for the **Probe <img src="https://latex.codecogs.com/svg.latex?\Large&space;\alpha"/> limit**. 

The next three values are **C1**, **C3**, and **C5**, corresponding to defocus, and the first two orders of spherical aberration respectively. The convention used in `Prismatic` is a probe defined by

<img src="https://latex.codecogs.com/svg.latex?\Large&space;\Psi(\vec{q}\,) = \exp[ -i \chi (\vec{q}\,)]"/> 

where

<img src="https://latex.codecogs.com/svg.latex?\Large&space;\chi(\vec{q}\,) = \pi \lambda |\vec{q}\,|^2 C_1 + \frac{\pi}{2} \lambda^3 |\vec{q}\,|^4 C_3 + \frac{\pi}{3} \lambda^5 |\vec{q}\,|^6 C_5"/> 

To keep this tutorial simple, we will assume an ideal microscope with no aberrations, where <span style="color:red">**C1 = C3 = C5 = 0**</span>.

The next parameter value on the right side is the **Random Seed**, which is only used to make the simulation more repeatable for testing - thus we do not care what this value is set to for the purposes of this tutorial. The next value is the **# of FP**, which means "number of frozen phonon (FP) configurations." These multiple FP configurations are used to average the scattering pathways due to thermal motion of the atoms over multiple simulations. All high accuracy simulations should use multiple FPs, and typically the more the better. I recommend using (at a minimum) 8 FPs for thick samples, and 32 FPs for thin samples. For this tutorial, we will use <span style="color:red">**1 FP**</span> configuration.

The next value is **Slice Thickness** which defines the spacing of potential slices used in the atomic potentials. A smaller value here will make the simulation more accurate, while a larger value will speed up the simulation. For this simulation we will use a typical value of <span style="color:red">**2 Angstroms**</span>. The last value in this column is **Detector Angle Step**, which is used for the 3D simulation output to specify the width of each annular bin used in the output integration. The 3D output is a series of concentric rings for different scattering angles, recorded for each probe position. This value should be small enough to allow any necessary virtual detector to be constructed from the simulation. We will use the default value of <span style="color:red">**1 mrad**</span>.



### Simulation Settings Block 3:

The final group of simulation settings deals with the `PRISM` interpolation factors, the STEM probe positions and tilts. We will be changing these settings later, but for now set **PRISM Interpolation Factors** to <span style="color:red">**4**</span> for both x and y.  The spacing of STEM probes is set by the **Probe Step** box, which we will set to <span style="color:red">**0.2 Angstroms**</span>. **Probe Tilt** should be set to <span style="color:red">**0 mrads**</span> for both x and y, and the **Scan Window** should run from <span style="color:red">**0 to 0.9999**</span> for both x and y. This will create a square grid of STEM probes that will cover the entire field of view. The reason to not set the maximum range to 1.0 is that if the probe step can be evenly divided into the simulation cell size, we would duplicate the probe located at 0.0 with the probe located at 1.0, due to the periodicity of the simulation.

Note that it is very important to remember the difference between **Pixel Size** and **Probe Step** settings, both in units of Angstroms. The **Pixel Size** setting refers to the sampling of pixels for the atomic potentials, the STEM probes, and the various numerical operator functions used during the simulation. By contrast, **Probe Step** refers only to the spacing of the STEM probes, and no other parts of the simulation. Later in the tutorial, we will for example run simulations consisting of only single STEM probe positions.

Now that you have entered the basic settings, your window should look like so:

![SuperSTEM screenshot 02](img/SuperSTEM/screenshot02.png){:width="898"}







<a name="step4"></a>
&nbsp;
## 4 - Calculate and view atomic potentials.

We can now start using `Prismatic` interactively, to determine the remaining settings for our simulation. This section will show you why it is very important to visualize your STEM simulation components, whether you are using the `PRISM` or `multislice` algorithms. Running a simulation blindly over a console (the first time) can easily cause you to overlook potential issues.

The first part of a STEM simulation is calculation of the atomic potentials. You can always run this part of the STEM simulation independently in `Prismatic`, by clicking on the **Calculate Potentials** button at the bottom the right hand side of the GUI. This should take only a few moments of CPU time. Next, select the **Potential** tab on the upper left corner. You will immediately see the first potential slice.  To see the sum of all slices, select the **Max** slider bar on the lower left and drag it all the way to the right, giving a slice range from 1 to 4 slices [***Bug*** - both sliders are labeled **Min**, but the lower one refers to **Max**]. To make it easier to view the potentials, you can next click on the **Square Root Intensity** check box. Your window should now look like this:

![SuperSTEM screenshot 03](img/SuperSTEM/screenshot03.png){:width="572"}

Note that the individual atomic columns do not form round peaks - why?  The answer is two-fold: first, what you are seeing is the randomly generated atomic displacements due to thermal motions (Debye-Waller effect). Relativistic electrons move **much** faster than ions in solid materials. To the electron beam, the ions appear to have (semi) random shifts "frozen" in, due to the large number of of phonons present in the material at any given time. Technically speaking, each electron will see a different frozen phonon configuration, but simulating this is impractical. Instead we use a number of "frozen phonon (FP) configurations" and sum the results incoherently. To see this in action, try changing **Random Seed** to different values, and then clicking on **Calculate Potentials** again.  For example on my laptop, changing the seed value gives these potentials:

![SuperSTEM screenshot 04](img/SuperSTEM/screenshot04.png){:width="518"}

There is a second reason why these shifts are so obvious - because the sample is extremely thin (<8 Angstroms). Because we are not yet tiling the cell along the beam direction, each atomic column has only a small number of atoms along the beam direction.  This is why more FP configurations are needed when running a simulation of a thin sample. Thicker samples will "average out" the atomic shifts to a greater degree. Note that all simulations used for quantitative analysis should still use multiple FP configurations, and more will always be more accurate. However we should also remember that we are not truly modeling the thermal motion of phonons inside a sample when we use random atomic shifts. Including correlations of the phonon wavevectors requires a much more accurate set of atomic positions, for example those calculated using molecular dynamics.








<a name="step5"></a>
&nbsp;
## 5 - Determine unit cell tiling.

The first problem with the simulation is that the cell is far too small, especially along the horizontal direction. Even a sub-Angstrom STEM probe will have tails reaching a diameter of 1 nm. Thus we must prevent wraparound errors due to periodicity, where the probe tails self-interact. `Prismatic` includes a build in tool to examine these possible issues, and you can reach it by clicking on the **Probe Analyzer** tab in the upper left.

The **Probe Analyzer** will compute STEM probes using both the `PRISM` and `multislice` algorithms. It consists of a few steps: first, specify where you want to place the test STEM probe. Here we will use <span style="color:red">**x = 11.1, y = 0 Angstroms**</span> for the initial test (middle of the left panel of the GUI). After specifying these settings, click on the **Calculate** button right next to the x,y position boxes. To better see the probe intensity, click on the **Log Scale** check box. You should see:

![SuperSTEM screenshot 05](img/SuperSTEM/screenshot05.png){:width="670"}

For now, ignore all of the panels except for the very center one, **Real Space Multislice**.  You can see where the STEM probe is located, halfway down the left and right edges (periodicity). In the middle of this panel, we see an interference pattern in the STEM probe due to this wraparound effect. To get rid of this artifact, we can tile the unit cell horizontally by changing **Tile Cells Y** from 1 to <span style="color:red">**2 unit cells**</span>. Next, recompute the STEM probe tests by clicking on **Calculate** in the middle of the left panel. You should see:

![SuperSTEM screenshot 06](img/SuperSTEM/screenshot06.png){:width="670"}

As you can see, the self-interference of the STEM probe is much reduced. Generally for atomic resolution simulations, I suggest unit cell dimensions of at least 20 Angstroms. However as we will see next, this guideline is often insufficient for thick simulation cells. The probe may start out fitting inside a 20 Angstrom cell, but after propagating some distance it can expand bue the large convergence semiangle and scattering from the atomic columns. We will now examine this effect. In order to speed up these calculations, first set the **PRISM Interpolation Factors** to <span style="color:red">**10**</span>. Next, create a 100 Angstrom simulation cell thickness by changing **Tile Cells Z* to <span style="color:red">**13 unit cells**</span>. Then click **Calculate** and look at the **Real Space Multislice** panel. You can also try setting **Tile Cells Z* to <span style="color:red">**26 unit cells**</span> for a 200 Angstrom thick simulation, or  <span style="color:red">**52 unit cells**</span> for a 400 Angstrom simulation thickness. See below:

![SuperSTEM screenshot 07](img/SuperSTEM/screenshot07.png){:width="520"}

However we should keep in mind that **Log Scale** intensity range does not necessarily give us a good idea of how much intensity of the STEM probe is actually present at some distance from the nominal probe position. But, the current STEM probe position is not representative of a "worst case scenario," where the probe scattering is maximized. To address both of these issues, first uncheck the **Log Scale** box and then move the STEM test probe to <span style="color:red">**x = 13.0, y = 9.2 Angstroms**</span>. Once again, try setting **Tile Cells Z** set to <span style="color:red">**13, 26 and 52 unit cells**</span>, clicking **Calculate** after each change. You will see the probe become more delocalized as the sample becomes thicker: (this image is not a direct representation of the GUI window)

![SuperSTEM screenshot 08](img/SuperSTEM/screenshot08.png){:width="634"}

Thus we arrive at the following conclusion: the total size of the simulation required to hold the probe after delocalization / scattering is determined by your own tolerance for the wraparound error for a given simulation.  If the degree of error is too high, the simple solution is to increase the size of the field of view.  For example, if you change **Tile Cells** from x = 1, y = 2, z = 52 unit cells to <span style="color:red">**x = 2, y = 4, z = 52 unit cells**</span> and then click **Calculate** we see that even on the logarithmic scale, the probe does not contain wraparound error:

![SuperSTEM screenshot 09](img/SuperSTEM/screenshot09.png){:width="1272"}

For the next sections of this tutorial, we will therefore set **Tile Cells** to <span style="color:red">**x = 2, y = 4, z = 26 unit cells**</span>.  If your computer is very slow, you may prefer to use settings of x = 1, y = 2, z = 26 unit cells. Note that we are using 26 unit cells (200 Angstrom thickness) instead of 52 unit cells to reduce the simulation time.





<a name="step6"></a>
&nbsp;
## 6 - Examine `PRISM` vs `multislice` accuracy.

Now we turn to the simulation algorithm itself, specifically the questions of whether to use `multislice` or `PRISM`, and if we do use `PRISM` which interpolation factors to use. We will continue to use the **Probe Analyzer** tab to answer these questions, located in the upper left of the GUI.  Keeping the x and y test probe locations the same as the previous section, set the **PRISM Interpolation Factors** to  <span style="color:red">**8**</span>. Next click the **Calculate** button, and while making sure the **Log Scale** check box is <span style="color:red">**unchecked**</span>. Next, examine the two panels labeled **Real Space `PRISM` and `Multislice`**, which should look something like:

![SuperSTEM screenshot 10](img/SuperSTEM/screenshot10b.png){:width="648"}

Clearly, the probe calculated by using the `PRISM` algorithm has been cropped at the edges compared to the `multislice` calculation. Examining the probes in the two below panels, **Fourier space** shows the large difference between the two simulations. And since `PRISM` is an approximation to a full `multislice` simulation, any difference between the two is due to inaccuracy of the `PRISM` simulation. Therefore we need to improve the simulation accuracy. Set the **PRISM Interpolation Factors** to <span style="color:red">**4**</span>, and click **Calculate**. Note that this will take substantially longer than using interpolation factors of 8.

![SuperSTEM screenshot 11](img/SuperSTEM/screenshot11b.png){:width="658"}

Much better!  The tails of the probe are cropped much further out in the **Real Space** images, and comparing the **Fourier Space** images shows that `PRISM` is now much closer to the `multislice` simulation.  However, if we click on the **Log Scale** check box, we can see that `PRISM` has still cropped the probe tails, shown here:

![SuperSTEM screenshot 12](img/SuperSTEM/screenshot12b.png){:width="658"}

If we want further accuracy, we can set the **PRISM Interpolation Factors** to <span style="color:red">**2**</span>, and then click **Calculate**.  **WARNING: only do this if your computer is fast / has a CUDA GPU!**. The results are shown here:

![SuperSTEM screenshot 13](img/SuperSTEM/screenshot13b.png){:width="656"}

While using an interpolation factor of 2 results in a highly accurate simulation, it is not necessary for reasonably accurate simulations where we investigate different bright field and dark field STEM images qualitatively. However if you are running a simulation for a quantitative scientific study, you may wish to increase the accuracy for the final simulation runs. For the next section of this tutorial, set the **PRISM Interpolation Factors** to <span style="color:red">**4**</span>. If you run the **Probe Analyzer** again with these settings and uncheck **Log Scale** you will see that an interpolation factor of 4 does contain almost all of the probe intensity.



<a name="step7"></a>
&nbsp;
## 7 - Run simulations using the `PRISM` algorithm.

We can now run some simulations!  The key question to answer in this section is to evaluate the difference in speed between a `PRISM` and `multislice` simulation. If `multislice` can be run quickly enough, I definitely recommend using it. It has the additional advantage that we do not need to worry about the errors introduced by using an interpolation factor that is too large.  So, let's start with `multislice` simulations.

Set the probe **Scan Window** range from <span style="color:red">**0 - 0.1 for both x and y**</span>. Next, in the **Calculation Settings** box, change the **Algorithm** from `PRISM` to  <span style="color:red">**`multislice`**</span>. After making sure both of these ranges are 10% of the field of view (0 to 0.1), click on **Full Calculation**. This simulation takes approximately 30 seconds on my GPU laptop.  If we were to scale that up to the entire field of view, the calculation time will increase by a factor of 100, making the total simulation time for a single FP configuration equal to about 50 minutes!  Because this is over 50% of the total tutorial time, we will not be running this simulation.

Next, set the **Algorithm** to <span style="color:red">**`PRISM`**</span>, and click on **Full Calculation**. On my GPU laptop, the second step of `PRISM` (calculate compact S-matrix) requires about 18 seconds, while the third step (probe output calculations) takes <2 seconds. This total calculation time of 20 seconds is barely better than the `multislice` algorithm time of 30 seconds ... or is it?  No, it is much, ***much*** better. Why?  The `PRISM` algorithm second step only need to be completed a single time - it is independent of the number of probes / size of the field of view of the output image. To show this, change **Scan Window** for x and y both to a range of <span style="color:red">**0 - 0.9999**</span>. After making these changes, click on the **Full Calculation** to run the entire `PRISM` simulation.  On my GPU laptop, the total calculation time is approximately 1 minute - a 50-fold speed up over the `multislice` algorithm!

After running this simulation, we will now use the interactive output portion of `Prismatic`, which you can access by clicking on the **Output** tab in the upper left corner of the GUI. Next, play with the slider bars at the bottom of the left side panel.  These sliders allow you to change the inner and outer detector angles, producing many different virtual STEM images. Try making these images:

![SuperSTEM screenshot 14](img/SuperSTEM/screenshot14.png){:width="1029"}

If your computer is fast enough, you can change the PRISM interpolation factors to <span style="color:red">**2**</span> and re-run the simulation. If your computer is slower, you can reduce the number of STEM probes being calculated (ask the instructor). The same figure as above, but for interpolation factors of 2 instead of 4 looks like:

![SuperSTEM screenshot 15](img/SuperSTEM/screenshot15.png){:width="1024"}

Comparing these two figures, we see the result of using `PRISM` interpolation factors that are too large (worse approximation). The bright field images appear almost identical in the two cases, i.e. when the outer angle of the annular detector is still contained in the original probe semiangle, the more approximate `PRISM` simulation with interpolation factor 4 can still produce fairly accurate contrast. However this is not true for the annular dark field images, when we are counting electrons primarily outside of the probe semiangle. The lower center and lower left images contain artifacts when the `PRISM` interpolation factors are set to 4. 

Thus we see why it is important to carefully check that the `PRISM` interpolation factors for accuracy. The best format method to do so is to run convergence tests comparing `PRISM` simulations to `multislice` - quite similar to how density functional theory (DFT) calculations must also be carefully checked for convergence.




<a name="step8"></a>
&nbsp;
## 8 - Save simulation results, save output images.

Currently `Prismatic` saves output files for image simulations as 3D arrays in this .mrc file format. This format is simple and can be loaded into Matlab, python, etc without too much effort. More output options will be added to `Prismatic` in the future. In order to save the 3D output in `Prismatic`, we need to input two settings.  The first is to check the box for **Save 3D Output**. Next, you must select a value path and output file name, and write them into the box labeled **Output File**. For example, on my laptop a valid output would be *"C:\Users\cophus\BaNdTiO_output.mrc"*. Once these settings are in place, you can re-run any simulation to generate the .mrc output file.

To save a single output image (also in .mrc format), we can use the option at the bottom of the left panel. First, specify the output file name, for example I am using *"C:\Users\cophus\BaNdTiO_image.mrc"*. Next, simply click on the **Save Current Image** to output the image file. We can also output the full image of each STEM probe for 4D-STEM applications. However this currently saves many tiny files in `Prismatic` and so we will not consider it here.

Finally, using a virtual detector from 60 - 92 mrads, on an accurate `PRISM` simulation of this sample with a thickness of 400 Angstroms, we can produce a simulation that is a very good match to the experimental dark field image: (experimental image courtesy of Demie Kepaptsoglou, F. Azough, and R. Freer)

![SuperSTEM screenshot 16](img/SuperSTEM/screenshot16.png){:width="837"}




<a name="step9"></a>
&nbsp;
## 9 - Further simulations.

This final section of the tutorial is where you can explore using `Prismatic` to perform other simulations. Try loading one or more of the other four .xyz files into `Prismatic` and run some `PRISM` simulations. Use what you have learned to balance the calculation speed with the accuracy, and if you have questions please just ask the instructors.








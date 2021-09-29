---
title: Prismatic Change log
subtitle: Changes added in new versions of Prismatic
---

## Changes introduced in `Prismatic` version 2.0
- Simulation capabilities for HRTEM imaging modes.
- 3D potential parameterization with subpixel shifting for higher quality projected potential calculations.
- A new S-matrix refocusing algorithm for improving accuracy of PRISM simulations with large defocus.
- Support for simulation series, such as defocus series.
- Improved IO support, including projected potential and S-matrix importing and exporting, and saving of the input probe.
- Support for calculating arbitrary scan patterns.
- Support for including arbitrary sets of aberrations in the imaging wavefunction.
- A postprocessing module and update to pyprismatic.
- Inclusion of soft-probe aperture for improved aliasing behavior for PRISM simulations.
- Updated potential parameterization coefficients to those tabulated in 3rd ed. of Kirland's Advanced Computing in Electron Microscopy.
- An updated GUI.
- Docker containers for easy, ready-to-use deployment of CLI and pyprismatic installations.
- Internal unit testing for accelerated development of new features.
- Improved 4D output performance.
- Overhauled internal IO interface.
- Other miscellaneous bug fixing and internal refactoring.

## Changes introduced in `Prismatic` version 1.2

- Fixed a bug where the same random seed could be passed to multiple CPU threads, leading to duplicated atomic shifts in potential slices.
- Added ability to output the simulation at multiple thicknesses / unit cell tiling repeats.
- Probe step size (sampling) can now be automatically used.
- Added support for HDF5 file saving.
- Added center-of-mass DPC outputs.
- Added the ability to pre-specify a detector range.
- Images are now saved in .png format.
- Many, many optimizations for cmake compiling . . . 
- pyprismatic updated!
---
title: Prismatic Change log
subtitle: Changes added in new versions of Prismatic
---


## Changes introduced in `Prismatic` version 1.2

- Fixed a bug where  the same random seed could be passed to multiple CPU threads, leading to duplicated atomic shifts in potential slices.
- Added ability to output the simulation at multiple thicknesses / unit cell tiling repeats.
- Probe step size (sampling) can now be automatically used.
- Added support for HDF5 file saving.
- Added center-of-mass DPC outputs.
- Added the ability to pre-specify a detector range.
- Images are now saved in .png format.
- Many, many optimizations for cmake compiling . . . 
- pyprismatic updated!


---

## Features planned for future releases

- Ability to specify arbitrary aberrations.
- Simulation of incoherent effects such as temporal (energy) spread, angular spread, finite source size, blurring due to mechanical vibration, etc.
- GUI overhaul.
- Ability to reload output files into the GUI.
- Closer integration of pyprismatic with py4DSTEM.
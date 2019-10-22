---
title: STEM Simulation Analysis
subtitle: Guide for using and analyzing STEM simulation results
---

`Prismatic`can simulate STEM simulations with 2D, 3D or even 4D outputs. By using a very small convergence angle (<1 reciprocal pixel), `Prismatic` can even simulate plane wave propagation, for example in diffraction pattern simulations. When performing 2D or 3D incoherent image simulations such as BF, ABF or ADF images, the outputs often require additional processing such as applying source size broading, and 2D Differential phase contrast (DPC) simulations require phase reconstruction. And finally, 4D-STEM simulations require a significant amount of additional processing for various experiments.  This page will eventually contain detailed information for working with various STEM simulation formats.



## 4D-STEM Analysis

For analyzing 4D-STEM simulations (and experiments), we recommend using a python package [py4DSTEM](https://github.com/py4dstem/py4DSTEM), an analysis code also developed at NCEM in Berkeley Lab. `Prismatic` already saves all output in an HDF5 format that is fully compatible with py4DSTEM. For more information about 4D-STEM, see this review paper:



[<img src="/img/STEMinfo/4DSTEM_review_cover.jpg">](https://www.cambridge.org/core/journals/microscopy-and-microanalysis/article/fourdimensional-scanning-transmission-electron-microscopy-4dstem-from-scanning-nanodiffraction-to-ptychography-and-beyond/A7E922A2C5BFD7FD3F208C537B872B7A#fndtn-information)






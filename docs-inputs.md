---
title: Input File Formats
---


# Atomic coordinate input format for Prismatic


**Note: Currently the input files must be encoded as ASCII text (UTF-8). If your text editor is using another encoding like UTF-16 you may experience errors**

Input files containing the atomic coordinates should be in the following XYZ format.

* 1 comment line
* 1 line with the 3 unit cell dimensions a,b,c (in Angstroms)
* *N* lines of the comma-separated form `Z`, `x`, `y`, `z`, `occ`, `thermal_sigma` where `Z` is the atomic number, `x`, `y`, and `z` are the coordinates of the atom within the unit cell in Angstroms, `occ` is the occupancy number (value between 0 and 1 that specifies the likelihood that an atom exists at that site), and `thermal_sigma` is the standard deviation of random thermal motion in Angstroms (Debye-Waller effect).
* -1 to indicate end of file

Here is a sample file, "SI100.XYZ" taken from Earl Kirkland's `computem` simulation program, which uses the same format:

~~~
one unit cell of (100) silicon
      5.43    5.43    5.43
  14  0.0000  0.0000  0.0000  1.0  0.076
  14  2.7150  2.7150  0.0000  1.0  0.076
  14  1.3575  4.0725  1.3575  1.0  0.076
  14  4.0725  1.3575  1.3575  1.0  0.076
  14  2.7150  0.0000  2.7150  1.0  0.076
  14  0.0000  2.7150  2.7150  1.0  0.076
  14  1.3575  1.3575  4.0725  1.0  0.076
  14  4.0725  4.0725  4.0725  1.0  0.076
  -1
~~~

# Probe Position input format for Prismatic

For performing arbitary scan patterns, an input text file containing the probe positons must be passed to `Prismatic`. 
The file format is similar to the input file for atomic coordinates:

* 1 comment line
* *N* lines of the comma-separated form `r_x`, `r_y` where `r_x` and `r_y` are the probe coordinates in X and Y. Coordinates
are taken as the real-space coordinates in units of angstroms, not fractional coordinates.
* -1 to indicate the end of the file.

Here is an example file which demonstrates an example of a diagonal zigzag scan pattern over a region of the sample:

~~~
zigzag scan pattern
0.0 0.0
2.5 2.5
5.0 5.0
2.5 7.5
0.0 10.0
2.5 12.5
5.0 15.0
2.5 17.5
0.0 20.0
-1
~~~

# Aberration file input format for Prismatic

For including arbitrary aberrations in the input wavefunction, an input text file enumerating the aberrations and their
relative weight must be passed to `Prismatic`. The file format is similar to the input file for atomic coordinates:

* 1 comment line
* *N* lines of the comma-separated form `m`, `n`, `C_mag`, `C_ang`, where `m` is the radial order of the aberration, 
`n` is the azimuthal order of the aberration, and `C_mag` and `C_ang` are dimensionless coefficients describing the 
aberration magnitude in rads and the azimuthal phase of the aberration, respectively.
* -1 to indicate the end of the file.

Here is an example file which demonstrates the inclusion of defocus, spherical aberration, and 3-fold coma and astigmtatism.

~~~
defocus, spherical, 3-fold coma, 3-fold astig
1 0 100 0
3 0 1000 0
3 1 5000 1.57
3 3 7500 0.75
-1
~~~

For a fuller discussion of appropriate setting of aberration coefficients and the relationship between various conventions, 
please refer to following references:

1. L. Rangel DaCosta, et. al, [Prismatic 2.0-
Simulation software for scanning and high resolution
transmission electron microscopy (STEM and HRTEM).](https://www.sciencedirect.com/science/article/pii/S0968432821001323)
Micron 151, 103141 (2021).

2. C. Ophus, et. al, [Automatic software correction of residual aberrations in reconstructed HRTEM exit waves of crystalline samples](https://link.springer.com/article/10.1186%2Fs40679-016-0030-1).
Advanced Structural and Chemical Imaging 2, (2016).

3. [Aberration-Corrected Analytical Transmission Electron Microscopy](https://onlinelibrary.wiley.com/doi/book/10.1002/9781119978848), Appendix A: Aberration Notation. R. Brydson, 2011.


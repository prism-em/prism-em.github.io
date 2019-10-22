---
title: Input File Format
subtitle: Atomic coordinate input format for Prismatic
---


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

---
title: GUI Programs
subtitle: Download binary installation files for Prismatic
---



# Current Version (`Prismatic v1.2.1`)

---
## Installers

### Windows 
[Prismatic-GPU-v1.2.1.msi](https://github.com/prism-em/prismatic/releases/download/1.2.1/Prismatic-GPU-v1.2.1.msi)

[Prismatic-v1.2.1.msi](https://github.com/prism-em/prismatic/releases/download/1.2.1/Prismatic-v1.2.1.msi)

### Mac OS X
v1.2.1 installer coming soon.

## Conda-forge packages

GPU or CPU Prismatic binaries are packaged on [conda-forge](https://conda-forge.org) for Windows, MacOS and Linux. They can be installed easily in an Anaconda/Miniconda distribution using the [conda](https://docs.conda.io) or [mamba](https://github.com/mamba-org/mamba) package manager.

To install all variants of prismatic, run from an Anaconda command prompt:

~~~
conda install prismatic -c conda-forge
~~~
If a CUDA compatible GPU is available, the GPU packages will be selected by default and a cudatoolkit [compatible with your GPU](https://docs.nvidia.com/deploy/cuda-compatibility/index.html) (Kepler and above) will be installed automatically. Otherwise, the CPU will be selected. To switch or explicitely select CPU packages, see instructions below. If you don't want to install all variants, you can install them separately.

To install prismatic CLI (`prismatic-cli` and `prismatic-double` for double precision):
~~~
conda install prismatic_cli -c conda-forge
~~~

To install prismatic GUI (`prismatic-gui`) with start menu shortcut on windows:
~~~
conda install prismatic_gui -c conda-forge
~~~

To install `pyprismatic`:
~~~
conda install pyprismatic -c conda-forge
~~~

To select CPU only packages, use the following syntax with any of the conda packages mentioned above:
~~~
conda install prismatic=*=cpu* -c conda-forge
~~~

## Source Code
[Current Build](http://www.github.com/prism-em/prismatic)

[Prismatic v1.2.1 zip file](https://github.com/prism-em/prismatic/archive/v1.2.1.zip)

[Prismatic v1.2.1 tar file](https://github.com/prism-em/prismatic/archive/v1.2.1.tar.gz)

---
---
---

# Old Versions
---
Please note that there are a variety of known issues with old versions. Installing the most recent version is guaranteed to provide safer, more accurate simulation capabilities.

## Installers

### Windows 
[Prismatic-v1.2.msi](https://github.com/prism-em/prismatic/releases/download/v1.2/Prismatic-v1.2.msi)

[Primatic-GPU-v1.2.msi](https://github.com/prism-em/prismatic/releases/download/v1.2/Prismatic-GPU-v1.2.msi)

[Prismatic-v1.1.msi](https://drive.google.com/open?id=13TZZc1ZAzMMx-cmfiCJCL4pBPqW_icWS)

[Prismatic-GPU-v1.1.msi](https://drive.google.com/open?id=1B9Yq-BBWY3VvNRD-aiKTWGzDME7s8qPh)  

[Prismatic-v1.0.msi](https://drive.google.com/open?id=13TZZc1ZAzMMx-cmfiCJCL4pBPqW_icWS)

[Prismatic-GPU-v1.0.msi](https://drive.google.com/open?id=1MiIWWZTqMEfl-eRi3HQDdgf3iNmIgDS-)

### Mac OS X
[Prismatic-MacOSx-GUI-v1.2.tar.gz](https://github.com/prism-em/prismatic/releases/download/v1.2/Prismatic-MacOSx-GUI-v1.2.tar.gz)

[Prismatic-OSX-v1.1.dmg (OSX 10.12.6 Sierra)](https://drive.google.com/open?id=1S1utdTErovvkf-o5P4gTRB5IeC4smYqZ)

[Prismatic-OSX-v1.1.dmg (OSX 10.13.1 High Sierra)](https://drive.google.com/open?id=1OnclVmfDv9oIAXVdTbq6dp94DDiLuWfk) 

[Prismatic-OSX-v1.0.dmg](https://github.com/prism-em/prismatic-binaries/raw/master/Mac/Prismatic-v1.0.dmg.zip)  

## Source Code

[Prismatic v1.2 zip file](https://github.com/prism-em/prismatic/archive/v1.2.zip)

[Prismatic v1.2 tar file](https://github.com/prism-em/prismatic/archive/v1.2.tar.gz)

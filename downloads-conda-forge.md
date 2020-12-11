---
title: Conda-forge
subtitle: Install using conda-forge packages
---


GPU or CPU Prismatic binaries are packaged on [conda-forge](https://conda-forge.org) for Windows, MacOS and Linux. They can be installed easily in an Anaconda/Miniconda distribution using the [conda](https://docs.conda.io) or [mamba](https://github.com/mamba-org/mamba) package manager.

The different variants of ``prismatic`` are available in 4 packages:
- ``prismatic_cli`` to install the command line version
- ``prismatic_gui`` to install the GUI version
- ``pyprismatic`` to install the python binding
- ``prismatic`` to install all 3 others packages

Each of these packages are available with CPU or GPU capabilities (``prismatic`` doesn't support GPU on MacOS). To install one of the packages, the [Anaconda navigator](https://docs.anaconda.com/anaconda/navigator) can be used.
Alternatively, one of the following commands can be ran from an Anaconda command prompt (on Windows) or a terminal (MacOS or Linux):

~~~
conda install prismatic -c conda-forge
~~~
If a CUDA compatible GPU is available, the GPU packages will be selected by default and a cudatoolkit [compatible with your GPU](https://docs.nvidia.com/deploy/cuda-compatibility/index.html) (Kepler and above) will be installed automatically. Otherwise, the CPU will be selected. To switch or explicitely select CPU packages, see instructions below.

The ``prismatic`` package is a meta-package which install the packages of each variant. If you don't want to install all variants, you can install them separately. 

To install prismatic CLI (``prismatic-cli`` and ``prismatic-double`` for double precision):
~~~
conda install prismatic_cli -c conda-forge
~~~

To install prismatic GUI (``prismatic-gui``) with start menu shortcut on windows:
~~~
conda install prismatic_gui -c conda-forge
~~~

To install ``pyprismatic``:
~~~
conda install pyprismatic -c conda-forge
~~~

## Select CPU or GPU build

To select CPU only packages, use the following syntax with any of the conda packages mentioned above:
~~~
conda install prismatic=*=cpu* -c conda-forge
~~~

GPU packages are prioritise by default and it can happen that this priority is overwritten by another priority when conda or mamba resolves the dependencies tree. To pin to a specific computing backend (CPU or GPU), use the [pinning mechanism](https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-pkgs.html#preventing-packages-from-updating-pinning) of conda, either through:

~~~
conda config --env --add pinned_packages prismatic=*=gpu*
~~~

or by adding the package name and its pinning to the following to the ``env_path/conda-meta/pinned`` file:
~~~
prismatic=*=gpu*
~~~


---
title: Source Code Walkthrough
---

*Written by AJ Pryor Jr*

Just because a project is open source doesn't mean that it is immediately obvious how all of its moving parts fit together.  I've spent a lot of time thinking about *Prismatic* and how to design it from a software engineering perspective, and I'm fairly satisfied with the result. This document is meant to be a sort of tour through the source code of *Prismatic* in a much more casual environment than a formal academic paper. This is not a tutorial for how to use the code (for more information see [here](http://prism-em.com/docs-params/)), but rather an explanation of the code itself. Thus it is more focused towards developers and less so to most users. For those of you who haven't frantically closed the browser at this point, I hope that you find it useful either as a GPU programming example, or as a guide to become a future developer of *Prismatic* itself.

## Table of Contents  
-  [A note on macros](#a-note-on-macros)  
-  [Work Dispatcher](#work-dispatcher)  
-  [Multidimensional Arrays](#multidim-arrays)  
-  [Metadata](#metadata)  
-  [Command Line Interface](#command-line-interface)  
-  [Configuration](#configuration)  
-  [PRISM](#prism)  
-  [Calculating Projected Potentials](#calculating-projected-potentials)  
-  [Prismatic GUI](#gui)
-  [Combining CUDA and Qt with CMake](#combining)

### A note on macros

The default floating-point precision used by *Prismatic* is `float` (single-precision) as this consumes less memory than double and on GPUs single-precision operations are faster than double. However, it is also possible to compile *Prismatic* for double precision. Many API calls in the cuFFT and FFTW libraries (as well as others) are different when invoking double or single-precision code. To make both precisions usable in `Prismatic`, there are a number of macro definitions set in "defines.h". 

~~~ c++
#ifdef PRISMATIC_ENABLE_DOUBLE_PRECISION
    typedef double PRISMATIC_FLOAT_PRECISION;
#define PRISM_FFTW_PLAN fftw_plan
#define PRISM_FFTW_PLAN_DFT_2D fftw_plan_dft_2d
#define PRISM_FFTW_PLAN_DFT_BATCH fftw_plan_many_dft
#define PRISM_FFTW_EXECUTE fftw_execute
#define PRISM_FFTW_DESTROY_PLAN fftw_destroy_plan
#define PRISM_FFTW_COMPLEX fftw_complex
#define PRISM_FFTW_INIT_THREADS fftw_init_threads
#define PRISM_FFTW_PLAN_WITH_NTHREADS fftw_plan_with_nthreads
#define PRISM_FFTW_CLEANUP_THREADS fftw_cleanup_threads

#else
    typedef float PRISMATIC_FLOAT_PRECISION;
#define PRISM_FFTW_PLAN fftwf_plan
#define PRISM_FFTW_PLAN_DFT_2D fftwf_plan_dft_2d
#define PRISM_FFTW_PLAN_DFT_BATCH fftwf_plan_many_dft
#define PRISM_FFTW_EXECUTE fftwf_execute
#define PRISM_FFTW_DESTROY_PLAN fftwf_destroy_plan
#define PRISM_FFTW_COMPLEX fftwf_complex
#define PRISM_FFTW_INIT_THREADS fftwf_init_threads
#define PRISM_FFTW_PLAN_WITH_NTHREADS fftwf_plan_with_nthreads
#define PRISM_FFTW_CLEANUP_THREADS fftwf_cleanup_threads
#endif //PRISM_ENABLE_DOUBLE_PRECISION
~~~

### Work Dispatcher

The `WorkDispatcher` class is critical to how parallel work is performed in *Prismatic*. Conceptually the idea is that there is a bunch of tasks to be done, and there exist a number of worker threads to do these tasks. At this level we don't really care how the worker is doing the work as long as it gets done. So the `WorkDispatcher` exists to hand out tasks to the workers in a synchronized manner, and is extremely simple to implement using `std::mutex`.

~~~ c++
// WorkDispatcher.h
#ifndef PRISM_WORKDISPATCHER_H
#define PRISM_WORKDISPATCHER_H
#include "params.h"
#include "configure.h"
#include <mutex>
namespace Prismatic {
    class WorkDispatcher {
    public:
        WorkDispatcher(size_t _current,
                       size_t _stop);

        bool getWork(size_t& job_start, size_t& job_stop, size_t num_requested=1, size_t cpu_early_stop=SIZE_MAX);
    private:
        std::mutex lock;
        size_t current, stop;
    };
}
#endif //PRISM_WORKDISPATCHER_H
~~~

Whenever we end up at a point in the calculation that we want to consume in parallel, you construct a single `WorkDispatcher` that holds a `mutex` and has a starting and stopping index representing all of the work. These indices might map to slices of the projected potential, for example. A reference to this work dispatcher is passed to all of the worker threads, who then request jobs with the `getWork` method. The implementation follows

~~~ c++
#include "WorkDispatcher.h"
#include <mutex>
// helper function for dispatching work

namespace Prismatic {
        WorkDispatcher::WorkDispatcher(size_t _current, size_t _stop): 
        current(_current), stop(_stop){};

		bool WorkDispatcher::getWork(size_t& job_start, size_t& job_stop, size_t num_requested, size_t early_cpu_stop){
			std::lock_guard<std::mutex> gatekeeper(lock);
			if (job_start >= stop | current>=early_cpu_stop) return false; // all jobs done, terminate
			job_start = current;
			job_stop = std::min(stop, current + num_requested);
			current = job_stop;
			return true;
		}
}
~~~

The constructor just initializes the relevant fields with the input parameters. The `getWork` function locks the mutex with a `std::lock_guard` in [RAII](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization) style such that it is guaranteed to be unlocked if anything bad happens. Everything after the creation of the `lock_guard` is synchronized, and the `WorkDispatcher` then tries to set `job_start` and `job_stop` to a range of `num_requested` jobs if possible, and fewer if necessary. It's really that simple.

<a name="multidim-arrays"></a>

### Multidimensional Arrays in *Prismatic* 

I built a custom multidimensional array class for *Prismatic*, mainly because I wanted to have full control over how the data was represented to get the best performance (i.e. make sure the data is always contiguous and use raw pointers when I could get away with it). The contiguous bit is super important. You could choose to represent multidimensional arrays in C++ as pointers-to-pointers or pointers-to-pointers-to-pointers, etc, which allows for enticing syntax like `data[0][0]`; however, this method allocates more memory and almost certainly allocates it discontiguously. This would totally kill your performance by causing each data access to invoke multiple pointer dereferences, requiring more operations and causing cache misses all over the place. Even if you use a clever trick to make repeated syntax bracket reduce to a single index, it generates unnecessary function call overhead. My solution was to instead store the data internally in a 1D buffer and then access it with a `.at()` member function that is aware of what the "actual" dimensionality of the `Prismatic::Array` is supposed to be. Because the last dimension changes the fastest in C-style ordering, I chose the syntax of the `at()` method to be slowest-to-fastest indices as you read left-to-right. For example that is `.at(y,x)` for a 2D array, `.at(z,y,x)` for a 3D array, etc so that "x" lies along the fastest changing dimension. By choosing `std::vector` to hold that 1D data buffer, I don't have to worry about `new`/`delete` or any other dynamic allocation business and garbage collection. Whenever I need to loop over the whole array (common), I also implemented the typical `begin()` and `end()` methods, which conveniently also allow for [range-based for loops](http://en.cppreference.com/w/cpp/language/range-for) with modern C++. The result is that many operations in *Prismatic* are efficient loops operating on and incrementing raw pointers.

I also added some convenience functions very similar to MATLAB's `zeros` and `ones`.. this was mainly to make my life easier when transcribing from Colin Ophus's original MATLAB prototype of PRISM.

The full class can be found in "ArrayND.h" and as it is some 600 lines that are fairly repetitive I won't include the whole thing here. But the following is a reasonable summary of what's important

~~~ c++
namespace Prismatic {
template <size_t N, class T>
class ArrayND {
        // ND array class for data indexed as C-style, i.e. arr.at(k,j,i) where i is the fastest varying index
        // and k is the slowest

        // T is expected to be a std::vector
    public:
        ArrayND(T _data,
                std::array<size_t, N> _dims);
        ArrayND(){};
		size_t get_dimi() const {return this->dims[N-1];}
		size_t get_dimj() const {return this->dims[N-2];}
		size_t get_dimk() const {return this->dims[N-3];}
		size_t get_diml() const {return this->dims[N-4]; }
		size_t get_dimm() const {return this->dims[N-5]; }
        size_t size()     const {return this->arr_size;}
        typename T::iterator begin();
        typename T::iterator end();
        typename T::const_iterator begin() const;
        typename T::const_iterator end()   const;
        typename T::value_type& at(const size_t& i);
        typename T::value_type& at(const size_t& j, const size_t& i);
        ///... many more declarations
        ///...
    
    private:
        std::array<size_t, N> dims;
        std::array<size_t, N-1> strides;
        size_t arr_size;
        T data;
}
    
// ... an example .at() implementation later in the file
  template <size_t N, class T>
typename T::value_type& ArrayND<N, T>::at(const size_t& k, const size_t& j,const size_t& i){
    return data[k*strides[0] + j*strides[1] + i];
}
~~~

So the template parameter `T` represents the underlying buffer data type, which must behave as `std::vector`. The other template parameter, `N`, is the number of dimensions in the array. The size of each dimension and corresponding array strides are computed at construction and stored in fixed arrays, and the `.at()` methods use these strides to compute offsets, such as in the example above for the 2D array case. The phrases like `typename T::value_type` are used to expose the underlying datatype within the buffer. For example, a `Prismatic::ArrayND<2, std::vector< float > >` is a 2D PRISM array where the underlying data is held in a single `std::vector<float>` and `typename T::value_type` resolves to `float`.

I say "behave as" for the data buffer, because originally I also intended this class to be able to contain `thrust::host_vector` and `thrust::device_vector`. This would allow one to effectively use one template class to wrap multidimensional arrays that can transfer data back and forth from the GPU without using the low level CUDA API calls. For example, you could overload the `=` operator for arrays of two different types and have the underying vector types copy from one another, also with the `=` operator. For example, `Prismatic::ArrayND<T> = Prismatic::ArrayND<U>` where `T` was a `thrust::host_vector` and `U` is a `thrust::device_vector` would invoke the assignment of a `thrust::host_vector` from a `thrust::device_vector`, calling `cudaMemcpy` under the hood without me having to do anything special. The same class simultaneously could be used to assign one `Prismatic::ArrayND<std::vector>` to another. All of the metadata about the dimensions, etc, are stored host-side, so in principle this template class would allow you to use one syntax across all your host/device arrays and not see many cuda device calls at all. I have also written about this topic before with the approach of template specialization -- you can read about that [here](http://alanpryorjr.com/2017-02-11-Flexible-CUDA/).

I still think this is a very good design pattern, but I ended up not using `thrust` at all, and the main reason was because I needed to manage page-locked memory in order to achieve asynchronous transfers. There is experimental support for a pinned memory allocator in thrust, `thrust::system::cuda::experimental::pinned_allocator< T >`, which can be passed into `thrust::host_vector`. However, with it being an experimental feature I was concerned about stability and figured if I was going to the trouble of customizing my array class specifically for performance I might as well also manually do my own allocations and not take risks. So ultimately `Prismatic::ArrayND< std::vector<T> >` was used for the pageable host-side arrays, and then raw pointer were used for pinned memory and the device arrays.

### Metadata

The primary way the simulation is setup is through the `Metadata` class. Simulation parameters that the user adjusts exist inside `Metadata` such as the electron energy, algorithm, slice thickness, PRISM interpolation factors, pixel size, etc. The metadata is then used to configure and execute the simulation. The nice thing about arranging the program in this way is that once you have a `Metadata` object it uniquely determines how to proceed with the rest of the simulation. The CLI, GUI, and Python package are just different ways to adjust the parameters in a `Metadata` object, but beyond that the executed code is the same. You can find the details of the `Metadata` template class in "meta.h" -- it's just a container for a number of variables. Yes, they are public instead of being private with setters/getters, which is normally frowned upon, but the only way these metadata values are changed is through higher level methods in the CLI and GUI, so in my opinion being "correct" would just introduce a bunch of extra unnecessary code.

### Command Line Interface

The CLI program, `prismatic`, is very simple.

~~~ c++
int main(int argc, const char** argv) {
	Prismatic::Metadata<PRISMATIC_FLOAT_PRECISION> meta;

	// parse command line options
	if (!Prismatic::parseInputs(meta, argc, &argv))return 1;

	// print metadata
        meta.toString();

	// configure simulation behavior
	Prismatic::configure(meta);

	// execute simulation
	Prismatic::execute_plan(meta);
	return 0;
}
~~~

The various command line options are parsed by the function `parseInputs`, which returns `true` if successful, otherwise the program exits. From there the configuration step is run (more on that later), and the calculation executed.

My take on a command line parser is simple. It uses a `std::map` to connect command argument keywords with functions that handle that particular argument. These functions all have the same signature. Using `std::map` allows for better lookup speed than a switch statement, but more importantly it makes it very easy to connect multiple keywords with the same parsing function. For example, I might have

~~~ c++
using parseFunction = bool (*)(Metadata<PRISMATIC_FLOAT_PRECISION>& meta,
                               int& argc, const char*** argv);
static std::map<std::string, parseFunction> parser{
        {"--input-file", parse_i}, {"-i", parse_i},
        {"--interp-factor", parse_f}, {"-f", parse_f}
        // ... more values follow
~~~

So the variable `parser` connects both the verbose and shorthand keywords "--interp-factor" and "-f" to the function `parse_f`, which is the function responsible for populating the PRISM interpolation factor in the metadata.

~~~ c++
bool parse_f(Metadata<PRISMATIC_FLOAT_PRECISION>& meta,
                    int& argc, const char*** argv){
    if (argc < 2){
        cout << "No interpolation factor provided for -f (syntax is -f interpolation_factor)\n";
        return false;
    }
    if ( (meta.interpolationFactorX = atoi((*argv)[1])) == 0){
        cout << "Invalid value \"" << (*argv)[1] << "\" provided for PRISM interpolation factors (syntax is -f interpolation_factor)\n";
        return false;
    }
    meta.interpolationFactorY = meta.interpolationFactorX;
    argc-=2;
    argv[0]+=2;
    return true;
};
~~~

I check that there are at least two remaining arguments, otherwise there isn't a factor provided and `false` is returned. Then the attempt is made to convert the factor to a number. If that fails we return `false`. Otherwise the parsing was successful, the value is set, and `argc` decremented and `argv` shifted. Some parsing functions might require more or fewer arguments, and with this design that's no problem because each option has a separate function. It also makes it very easy to add new options -- I just write the logic for parsing that argument, and then connect whatever keywords with the function name.

### Configuration

Several places in *Prismatic* there are divergences in how the simulation proceeds, such as whether to perform the calculation with multislice or PRISM. Rather than constantly having if-then-else statements for this type of logic, I'll instead create a single function pointer that is set to point to the desired behavior by the `configure` function. For example, both PRISM and multislice have entrypoint functions, cleverly named `PRISM_entry` and `Multislice_entry`. There is as corresponding function pointer defined in "configure.h" that is the `execute_plan` function used earlier in the driver:

~~~ c+++
//configure.h
using entry_func = Parameters<PRISMATIC_FLOAT_PRECISION>  (*)(Metadata<PRISMATIC_FLOAT_PRECISION>&);
entry_func execute_plan;
~~~

and this is set in `configure` within "configure.cpp"

~~~ c++
//configure.cpp
void configure(Metadata<PRISMATIC_FLOAT_PRECISION>& meta) {
/*
// more code..
*/
if (meta.algorithm == Algorithm::PRISM) {
	execute_plan = PRISM_entry;
	//...
	// bunch of other stuff..
	// ...
} else if (meta.algorithm == Algorithm::Multislice){	
	execute_plan = Multislice_entry;
}

/*
// more code..
*/
}
~~~

If you think this is overkill, and I could just have an if-else for this case, consider that there are choices of PRISM/multislice, the possibility of CPU-only or GPU-enabled, the possibility of streaming/singlexfer if we are using the GPU codes, etc. It would create a lot of divergences very quickly, and this is a better solution.

## PRISM

The `PRISM_entry` function is the top-tier control function for PRISM calculations, and handles running each of the steps and computing the various frozen phonon configurations. PRISM is divided into 3 steps:

1. Compute projected potentials
2. Compute compact S-matrix
3. Compute final output

During each of these steps, a number of different data structures are created and modified. To organize these internally-used arrays, a `Parameters` class is used. So we now have two wrapping classes: `Metadata`, which contains the user-adjustable parameters, and `Parameters`, which contains the internally modified data structures. This prevents having to juggle around a lot of inputs for each function call, and makes things easier to read.

### Computing projected potentials

~~~ c++
#include "PRISM_entry.h"
#include <iostream>
#include <stdlib.h>
#include <algorithm>
#include "configure.h"
#include "ArrayND.h"
#include "PRISM01_calcPotential.h"
#include "PRISM02_calcSMatrix.h"
#include "PRISM03_calcOutput.h"
#include "params.h"
#include <vector>

namespace Prismatic{
	using namespace std;
	Parameters<PRISMATIC_FLOAT_PRECISION> PRISM_entry(Metadata<PRISMATIC_FLOAT_PRECISION>& meta){
		Parameters<PRISMATIC_FLOAT_PRECISION> prismatic_pars;
		try { // read in atomic coordinates
			prismatic_pars = Parameters<PRISMATIC_FLOAT_PRECISION>(meta);
		} catch(const std::runtime_error &e){
			std::cout << "Terminating" << std::endl;
			exit(1);
		}

		// compute projected potentials
		PRISM01_calcPotential(prismatic_pars);

		// compute compact S-matrix
		PRISM02_calcSMatrix(prismatic_pars);

		// compute final output
		PRISM03_calcOutput(prismatic_pars);

		// calculate remaining frozen phonon configurations
        if (prismatic_pars.meta.numFP > 1) {
            // run the rest of the frozen phonons
            Array3D<PRISMATIC_FLOAT_PRECISION> net_output(prismatic_pars.output);
            for (auto fp_num = 1; fp_num < prismatic_pars.meta.numFP; ++fp_num){
	            meta.random_seed = rand() % 100000;
				Parameters<PRISMATIC_FLOAT_PRECISION> prismatic_pars(meta);
                cout << "Frozen Phonon #" << fp_num << endl;
	            prismatic_pars.meta.toString();
	        	PRISM01_calcPotential(prismatic_pars);
	        	PRISM02_calcSMatrix(prismatic_pars);
                PRISM03_calcOutput(prismatic_pars);
                net_output += prismatic_pars.output;
            }
            // divide to take average
            for (auto&i:net_output) i/=prismatic_pars.meta.numFP;
	        prismatic_pars.output = net_output;
        }
        if (prismatic_pars.meta.save3DOutput)prismatic_pars.output.toMRC_f(prismatic_pars.meta.filename_output.c_str());

		if (prismatic_pars.meta.save2DOutput) {
			size_t lower = std::max((size_t)0, (size_t)(prismatic_pars.meta.integration_angle_min / prismatic_pars.meta.detector_angle_step));
			size_t upper = std::min((size_t)prismatic_pars.detectorAngles.size(), (size_t)(prismatic_pars.meta.integration_angle_max / prismatic_pars.meta.detector_angle_step));
			Array2D<PRISMATIC_FLOAT_PRECISION> prism_image;
			prism_image = zeros_ND<2, PRISMATIC_FLOAT_PRECISION>(
					{{prismatic_pars.output.get_dimk(), prismatic_pars.output.get_dimj()}});
			for (auto y = 0; y < prismatic_pars.output.get_dimk(); ++y) {
				for (auto x = 0; x < prismatic_pars.output.get_dimj(); ++x) {
					for (auto b = lower; b < upper; ++b) {
						prism_image.at(y, x) += prismatic_pars.output.at(y, x, b);
					}
				}
			}
			std::string image_filename = std::string("prism_2Doutput_") + prismatic_pars.meta.filename_output;
			prism_image.toMRC_f(image_filename.c_str());
		}

        std::cout << "PRISM Calculation complete.\n" << std::endl;
		return prismatic_pars;
	}
}
~~~

The `Parameters` object is created (it takes the metadata as one the parameters to its constructor). Next an attempt is made to read the atomic coordinates, and if that fails then the program terminates. If the atoms are successfully read, we then execute each of the three steps. Last we handle the remaining frozen phonons, average the results, and save the output.

## Calculating Projected Potentials

Now we assemble the projected potentials by computing the digitized potential for each atomic species and storing it in a lookup table. The full sliced and projected potential is then calculated by dividing the model into slices and using this lookup table to build each slice.

#### Assembling the lookup table

~~~c++
	void PRISM01_calcPotential(Parameters<PRISMATIC_FLOAT_PRECISION>& pars){
		//builds projected, sliced potential

		// setup some coordinates
		cout << "Entering PRISM01_calcPotential" << endl;
		PRISMATIC_FLOAT_PRECISION yleng = std::ceil(pars.meta.potBound / pars.pixelSize[0]);
		PRISMATIC_FLOAT_PRECISION xleng = std::ceil(pars.meta.potBound / pars.pixelSize[1]);
		ArrayND<1, vector<long> > xvec(vector<long>(2*(size_t)xleng + 1, 0),{{2*(size_t)xleng + 1}});
		ArrayND<1, vector<long> > yvec(vector<long>(2*(size_t)yleng + 1, 0),{{2*(size_t)yleng + 1}});
		{
			PRISMATIC_FLOAT_PRECISION tmpx = -xleng;
			PRISMATIC_FLOAT_PRECISION tmpy = -yleng;
			for (auto &i : xvec)i = tmpx++;
			for (auto &j : yvec)j = tmpy++;
		}
		Array1D<PRISMATIC_FLOAT_PRECISION> xr(vector<PRISMATIC_FLOAT_PRECISION>(2*(size_t)xleng + 1, 0),{{2*(size_t)xleng + 1}});
		Array1D<PRISMATIC_FLOAT_PRECISION> yr(vector<PRISMATIC_FLOAT_PRECISION>(2*(size_t)yleng + 1, 0),{{2*(size_t)yleng + 1}});
		for (auto i=0; i < xr.size(); ++i)xr[i] = (PRISMATIC_FLOAT_PRECISION)xvec[i] * pars.pixelSize[1];
		for (auto j=0; j < yr.size(); ++j)yr[j] = (PRISMATIC_FLOAT_PRECISION)yvec[j] * pars.pixelSize[0];

		vector<size_t> unique_species = get_unique_atomic_species(pars);

		// initialize the lookup table
		Array3D<PRISMATIC_FLOAT_PRECISION> potentialLookup = zeros_ND<3, PRISMATIC_FLOAT_PRECISION>({{unique_species.size(), 2*(size_t)yleng + 1, 2*(size_t)xleng + 1}});
		
		// precompute the unique potentials
		fetch_potentials(potentialLookup, unique_species, xr, yr);

		// populate the slices with the projected potentials
		generateProjectedPotentials(pars, potentialLookup, unique_species, xvec, yvec);
	}
~~~

`get_unique_atomic_species` just determines the minimal set of elements in the sample -- no point in precomputing the potential for atoms we don't have. `fetch_potentials` builds the lookup table based upon the relevant coordinates, which are determined by the pixel size and `potBound`, and then `generateProjectedPotentials` builds the full projected/sliced potential.

Next is a big chunk of code that is conceptually accomplishing a simple task. Based on the relevant coordinates determined by the simulation pixel size, we compute the potential of each relevant element following Kirkland's book ["Advanced Computing in Electron Microscopy"](https://link.springer.com/book/10.1007%2F978-1-4419-6533-2) on an 8x supersampled grid, then integrate it, and store it.

~~~c++
void fetch_potentials(Array3D<PRISMATIC_FLOAT_PRECISION>& potentials,
                      const vector<size_t>& atomic_species,
                      const Array1D<PRISMATIC_FLOAT_PRECISION>& xr,
                      const Array1D<PRISMATIC_FLOAT_PRECISION>& yr){
	Array2D<PRISMATIC_FLOAT_PRECISION> cur_pot;
	for (auto k =0; k < potentials.get_dimk(); ++k){
		Array2D<PRISMATIC_FLOAT_PRECISION> cur_pot = projPot(atomic_species[k], xr, yr);
		for (auto j = 0; j < potentials.get_dimj(); ++j){
			for (auto i = 0; i < potentials.get_dimi(); ++i){
				potentials.at(k,j,i) = cur_pot.at(j,i);
			}
		}
	}
}
	
Array2D<PRISMATIC_FLOAT_PRECISION> projPot(const size_t &Z,
                                       const Array1D<PRISMATIC_FLOAT_PRECISION> &xr,
                                       const Array1D<PRISMATIC_FLOAT_PRECISION> &yr) {
	// compute the projected potential for a given atomic number following Kirkland

	// setup some constants
	static const PRISMATIC_FLOAT_PRECISION pi = std::acos(-1);
	PRISMATIC_FLOAT_PRECISION ss    = 8;
	PRISMATIC_FLOAT_PRECISION a0    = 0.5292;
	PRISMATIC_FLOAT_PRECISION e     = 14.4;
	PRISMATIC_FLOAT_PRECISION term1 = 4*pi*pi*a0*e;
	PRISMATIC_FLOAT_PRECISION term2 = 2*pi*pi*a0*e;

	// initialize array
	ArrayND<2, std::vector<PRISMATIC_FLOAT_PRECISION> > result = zeros_ND<2, PRISMATIC_FLOAT_PRECISION>({{yr.size(), xr.size()}});

	// setup some coordinates
	const PRISMATIC_FLOAT_PRECISION dx = xr[1] - xr[0];
	const PRISMATIC_FLOAT_PRECISION dy = yr[1] - yr[0];

	PRISMATIC_FLOAT_PRECISION start = -(ss-1)/ss/2;
	const PRISMATIC_FLOAT_PRECISION step  = 1/ss;
	const PRISMATIC_FLOAT_PRECISION end   = -start;
	vector<PRISMATIC_FLOAT_PRECISION> sub_data;
	while (start <= end){
		sub_data.push_back(start);
		start+=step;
	}
	ArrayND<1, std::vector<PRISMATIC_FLOAT_PRECISION> > sub(sub_data,{{sub_data.size()}});

	std::pair<Array2D<PRISMATIC_FLOAT_PRECISION>, Array2D<PRISMATIC_FLOAT_PRECISION> > meshx = meshgrid(xr, sub*dx);
	std::pair<Array2D<PRISMATIC_FLOAT_PRECISION>, Array2D<PRISMATIC_FLOAT_PRECISION> > meshy = meshgrid(yr, sub*dy);

	ArrayND<1, std::vector<PRISMATIC_FLOAT_PRECISION> > xv = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{meshx.first.size()}});
	ArrayND<1, std::vector<PRISMATIC_FLOAT_PRECISION> > yv = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{meshy.first.size()}});
	{
		auto t_x = xv.begin();
		for (auto j = 0; j < meshx.first.get_dimj(); ++j) {
			for (auto i = 0; i < meshx.first.get_dimi(); ++i) {
				*t_x++ = meshx.first.at(j, i) + meshx.second.at(j, i);
			}
		}
	}

	{
		auto t_y = yv.begin();
		for (auto j = 0; j < meshy.first.get_dimj(); ++j) {
			for (auto i = 0; i < meshy.first.get_dimi(); ++i) {
				*t_y++ = meshy.first.at(j, i) + meshy.second.at(j, i);
			}
		}
	}

	std::pair<Array2D<PRISMATIC_FLOAT_PRECISION>, Array2D<PRISMATIC_FLOAT_PRECISION> > meshxy = meshgrid(yv, xv);
	ArrayND<2, std::vector<PRISMATIC_FLOAT_PRECISION> > r2 = zeros_ND<2, PRISMATIC_FLOAT_PRECISION>({{yv.size(), xv.size()}});
	ArrayND<2, std::vector<PRISMATIC_FLOAT_PRECISION> > r  = zeros_ND<2, PRISMATIC_FLOAT_PRECISION>({{yv.size(), xv.size()}});

	{
		auto t_y = r2.begin();
		for (auto j = 0; j < meshxy.first.get_dimj(); ++j) {
			for (auto i = 0; i < meshxy.first.get_dimi(); ++i) {
				*t_y++ = pow(meshxy.first.at(j,i),2) + pow(meshxy.second.at(j,i),2);
			}
		}
	}

	for (auto i = 0; i < r.size(); ++i)r[i] = sqrt(r2[i]);
	// construct potential
	ArrayND<2, std::vector<PRISMATIC_FLOAT_PRECISION> > potSS  = ones_ND<2, PRISMATIC_FLOAT_PRECISION>({{r2.get_dimj(), r2.get_dimi()}});

	// get the relevant table values
	std::vector<PRISMATIC_FLOAT_PRECISION> ap;
	ap.resize(n_parameters);
	for (auto i = 0; i < n_parameters; ++i){
		ap[i] = fparams[(Z-1)*n_parameters + i];
	}

	// compute the potential
	using namespace boost::math;
	std::transform(r.begin(), r.end(),
	               r2.begin(), potSS.begin(), [&ap, &term1, &term2](const PRISMATIC_FLOAT_PRECISION& r_t, const PRISMATIC_FLOAT_PRECISION& r2_t){

				return term1*(ap[0] *
				              cyl_bessel_k(0,2*pi*sqrt(ap[1])*r_t)          +
				              ap[2]*cyl_bessel_k(0,2*pi*sqrt(ap[3])*r_t)    +
				              ap[4]*cyl_bessel_k(0,2*pi*sqrt(ap[5])*r_t))   +
				       term2*(ap[6]/ap[7]*exp(-pow(pi,2)/ap[7]*r2_t) +
				              ap[8]/ap[9]*exp(-pow(pi,2)/ap[9]*r2_t)        +
				              ap[10]/ap[11]*exp(-pow(pi,2)/ap[11]*r2_t));
			});

	// integrate
	ArrayND<2, std::vector<PRISMATIC_FLOAT_PRECISION> > pot = zeros_ND<2, PRISMATIC_FLOAT_PRECISION>({{yr.size(), xr.size()}});
	for (auto sy = 0; sy < ss; ++sy){
		for (auto sx = 0; sx < ss; ++sx) {
			for (auto j = 0; j < pot.get_dimj(); ++j) {
				for (auto i = 0; i < pot.get_dimi(); ++i) {
					pot.at(j, i) += potSS.at(j*ss + sy, i*ss + sx);
				}
			}
		}
	}
	pot/=(ss*ss);

	PRISMATIC_FLOAT_PRECISION potMin = get_potMin(pot,xr,yr);
	pot -= potMin;
	transform(pot.begin(),pot.end(),pot.begin(),[](PRISMATIC_FLOAT_PRECISION& a){return a<0?0:a;});

	return pot;
}	
~~~

#### Building the sliced potentials

First there's a bit of setup and we figure out which slice index each atom belongs to

~~~ c++
void generateProjectedPotentials(Parameters<PRISMATIC_FLOAT_PRECISION>& pars,
                                 const Array3D<PRISMATIC_FLOAT_PRECISION>& potentialLookup,
                                 const vector<size_t>& unique_species,
                                 const Array1D<long>& xvec,
                                 const Array1D<long>& yvec){
	// splits the atomic coordinates into slices and computes the projected potential for each.

	// create arrays for the coordinates
	Array1D<PRISMATIC_FLOAT_PRECISION> x     = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{pars.atoms.size()}});
	Array1D<PRISMATIC_FLOAT_PRECISION> y     = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{pars.atoms.size()}});
	Array1D<PRISMATIC_FLOAT_PRECISION> z     = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{pars.atoms.size()}});
	Array1D<PRISMATIC_FLOAT_PRECISION> ID    = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{pars.atoms.size()}});
	Array1D<PRISMATIC_FLOAT_PRECISION> sigma = zeros_ND<1, PRISMATIC_FLOAT_PRECISION>({{pars.atoms.size()}});

	// populate arrays from the atoms structure
	for (auto i = 0; i < pars.atoms.size(); ++i){
		x[i]     = pars.atoms[i].x * pars.tiledCellDim[2];
		y[i]     = pars.atoms[i].y * pars.tiledCellDim[1];
		z[i]     = pars.atoms[i].z * pars.tiledCellDim[0];
		ID[i]    = pars.atoms[i].species;
		sigma[i] = pars.atoms[i].sigma;
	}

	// compute the z-slice index for each atom
	auto max_z = std::max_element(z.begin(), z.end());
	Array1D<PRISMATIC_FLOAT_PRECISION> zPlane(z);
	std::transform(zPlane.begin(), zPlane.end(), zPlane.begin(), [&max_z, &pars](PRISMATIC_FLOAT_PRECISION &t_z) {
		return round((-t_z + *max_z) / pars.meta.sliceThickness + 0.5) - 1; // If the +0.5 was to make the first slice z=1 not 0, can drop the +0.5 and -1
	});
	max_z = std::max_element(zPlane.begin(), zPlane.end());
	pars.numPlanes = *max_z + 1;
	
#ifdef PRISM_BUILDING_GUI
	pars.progressbar->signalPotentialUpdate(0, pars.numPlanes);
#endif

~~~

A new idiom you see here is `#ifdef PRISM_BUILDING_GUI`. There is a progress bar that pops up in the GUI, and this macro is used to indicate whether or not to update it. When this source file is included in the CLI, `prismatic`, this macro is not defined, and thus the CLI doesn't need any of the Qt libraries that would be required to define this progress bar.

Next we calculate the actual potentials, and this is the first time we encounter the `WorkDispatcher` in action. In this case, each slice of the potential is a different job, and  CPU threads will be spawned to populate each slice.

~~~ c++
// initialize the potential array
pars.pot = zeros_ND<3, PRISMATIC_FLOAT_PRECISION>({{pars.numPlanes, pars.imageSize[0], pars.imageSize[1]}});
~~~

As an aside, this `zeros_ND` function is essentially an implementation of MATLAB's `zeros` and creates a multidimensional array built on `std::vector` and is 0-initialized. 

Now we make the `WorkDispatcher`, passing the lower and upper bounds of the work IDs into its constructor. The threads are then spawned and handed a lambda function defining the work loop. Each thread repeatedly calls `dispatcher.getWork`, which you'll recall from earlier returns true if a job was given. As long as work was provided, the thread will keep working, and once all the work is done the `WorkDispatcher` will begin returning false and the threads will finish. The main thread doesn't do any work -- it spawns the worker threads and then will wait at the line  `for (auto &t:workers)t.join();` until all the worker threads finish. The `join()` function is how you synchronize this multithreaded code. So the only parts that require synchronization are when each threads queries the `WorkDispatcher` and then when the main thread waits for the workers. The order in which the slices are worked on is nondeterministic. By the way, if you are wondering the cost of locking a mutex to hand out a work ID to each thread is completely negligible compared to how long it takes to do the work. The `WorkDispatcher` synchronization is effectively free.

~~~ c++
// create a key-value map to match the atomic Z numbers with their place in the potential lookup table
map<size_t, size_t> Z_lookup;
for (auto i = 0; i < unique_species.size(); ++i)Z_lookup[unique_species[i]] = i;

//loop over each plane, perturb the atomic positions, and place the corresponding potential at each location
// using parallel calculation of each individual slice
std::vector<std::thread> workers;
workers.reserve(pars.meta.NUM_THREADS);

WorkDispatcher dispatcher(0, pars.numPlanes);
for (long t = 0; t < pars.meta.NUM_THREADS; ++t){
	cout << "Launching thread #" << t << " to compute projected potential slices\n";
	workers.push_back(thread([&pars, &x, &y, &z, &ID, &Z_lookup, &xvec, &sigma,
									 &zPlane, &yvec,&potentialLookup, &dispatcher](){
		// create a random number generator to simulate thermal effects
		std::default_random_engine de(pars.meta.random_seed);
		normal_distribution<PRISMATIC_FLOAT_PRECISION> randn(0,1);
		Array1D<long> xp;
		Array1D<long> yp;

		size_t currentBeam, stop;
        currentBeam=stop=0;
		while (dispatcher.getWork(currentBeam, stop)) { // synchronously get work assignment
			Array2D<PRISMATIC_FLOAT_PRECISION> projectedPotential = zeros_ND<2, PRISMATIC_FLOAT_PRECISION>({{pars.imageSize[0], pars.imageSize[1]}});
			while (currentBeam != stop) {
				for (auto a2 = 0; a2 < x.size(); ++a2) {
					if (zPlane[a2] == currentBeam) {
						const long dim0 = (long) pars.imageSize[0];
						const long dim1 = (long) pars.imageSize[1];
						const size_t cur_Z = Z_lookup[ID[a2]];
						PRISMATIC_FLOAT_PRECISION X, Y;
						if (pars.meta.include_thermal_effects) { // apply random perturbations
							X = round((x[a2] + randn(de) * sigma[a2]) / pars.pixelSize[1]);
							Y = round((y[a2] + randn(de) * sigma[a2]) / pars.pixelSize[0]);
						} else {
							X = round((x[a2]) / pars.pixelSize[1]); // this line uses no thermal factor
							Y = round((y[a2]) / pars.pixelSize[0]); // this line uses no thermal factor
						}
						xp = xvec + (long) X;
						for (auto &i:xp)i = (i % dim1 + dim1) % dim1; // make sure to get a positive value

						yp = yvec + (long) Y;
						for (auto &i:yp) i = (i % dim0 + dim0) % dim0;// make sure to get a positive value
						for (auto ii = 0; ii < xp.size(); ++ii) {
							for (auto jj = 0; jj < yp.size(); ++jj) {
								// fill in value with lookup table
								projectedPotential.at(yp[jj], xp[ii]) += potentialLookup.at(cur_Z, jj, ii);
							}
						}
					}
				}
				// copy the result to the full array
				copy(projectedPotential.begin(), projectedPotential.end(),&pars.pot.at(currentBeam,0,0));
#ifdef PRISM_BUILDING_GUI
                pars.progressbar->signalPotentialUpdate(currentBeam, pars.numPlanes);
#endif //PRISM_BUILDING_GUI
				++currentBeam;
			}
		}
	}));
}
	cout << "Waiting for threads...\n";
	for (auto &t:workers)t.join();
#ifdef PRISM_BUILDING_GUI
	pars.progressbar->setProgress(100);
#endif //PRISM_BUILDING_GUI
};
~~~

### Compute Compact S-Matrix

The calculation of the compact S-Matrix is very similar to multislcie. To break things up, the various steps are broken up into subfunctions.

~~~c++
void PRISM02_calcSMatrix(Parameters<PRISMATIC_FLOAT_PRECISION> &pars) {
	// propagate plane waves to construct compact S-matrix

	cout << "Entering PRISM02_calcSMatrix" << endl;

	// setup some coordinates
	setupCoordinates(pars);

	// setup the beams and their indices
	setupBeams(pars);

	// setup coordinates for nonzero values of compact S-matrix
	setupSMatrixCoordinates(pars);

	cout << "Computing compact S matrix" << endl;

	// populate compact S-matrix
	fill_Scompact(pars);

	// only keep the relevant/nonzero Fourier components
	downsampleFourierComponents(pars);
}
~~~

`setupCoordinates`, `setupBeams`, and `setupSMatrixCoordinates` are not particularly interesting for the purpose of this document -- they just are allocating some arrays and figuring out which plane waves need to be computed for the given simulation settings. The important function is `fill_Scompact`, which is the first place we may encounter GPU code and is instance of a function pointer that is set by `Prismatic::configure` (in this case, it is set to either point to a CPU or CPU+GPU implementation to calculate the S-Matrix).

The CPU+GPU code includes the CPU code, so I'll just discuss the former here. The CPU+GPU code contains two memory models, the streaming and the single-transfer. The streaming code is essentially the same as the single-transfer except that there are additional calls to `cudaMemcpyAsync`. Therefore, I'll just discuss the streaming CPU+GPU version and you can look at the full source code for the details of the others. 

There is a `CudaParameters` for the same reasons as the `Parameters` class exists -- mostly to keep things organized and avoid having very elaborate function signatures. Again, I break everything up into smaller functions to make it easier to understand. Because this is the first code we're looking at that includes CUDA API calls and kernel invocations I'll explain in a bit more detail each of these.

~~~c++
void fill_Scompact_GPU_streaming(Parameters <PRISMATIC_FLOAT_PRECISION> &pars) {

#ifdef PRISM_BUILDING_GUI
	pars.progressbar->signalDescriptionMessage("Computing compact S-matrix");
	pars.progressbar->signalScompactUpdate(-1, pars.numberBeams);
#endif
	// This version streams each slice of the transmission matrix, which is less efficient but can tolerate very large arrays
	//initialize data
	CudaParameters<PRISMATIC_FLOAT_PRECISION> cuda_pars;

	// determine the batch size to use
	pars.meta.batch_size_GPU = min(pars.meta.batch_size_target_GPU, max((size_t)1, pars.numberBeams / max((size_t)1,(pars.meta.NUM_STREAMS_PER_GPU*pars.meta.NUM_GPUS))));

	// setup some arrays
	setupArrays2(pars);

	// create CUDA streams and cuFFT plans
	createStreamsAndPlans2(pars, cuda_pars);

	// create page-locked (pinned) host memory buffers
	allocatePinnedHostMemory_streaming2(pars, cuda_pars);

	// copy to pinned memory
	copyToPinnedMemory_streaming2(pars, cuda_pars);

	// allocate memory on the GPUs
	allocateDeviceMemory_streaming2(pars, cuda_pars);

	// copy to GPUs
	copyToDeviceMemory_streaming2(pars, cuda_pars);

	// launch workers
	launchWorkers_streaming(pars, cuda_pars);

	// free memory on the host/device
	cleanupMemory2(pars, cuda_pars);
}
~~~

The batch size correction is to avoid a scenario where the batch size is too big for the number of streams and GPUs being used. Remember, the batch size represents a number of plane waves that will be propagated simultaneously using batch FFTs. If the batch size is large enough that one of the streams isn't going to receive any work, then that will most likely hurt performance more than any benefit from batching, so this line is to check for that. Now for each of the helper functions

`setupArrays2`: build the transmission function by exponentiating the potential with the scale factor `sigma` and initialize the compact S-matrix.

~~~c++
inline void setupArrays2(Parameters<PRISMATIC_FLOAT_PRECISION>& pars){

	// setup some needed arrays
	const PRISMATIC_FLOAT_PRECISION pi = acos(-1);
	const std::complex<PRISMATIC_FLOAT_PRECISION> i(0, 1);
	pars.Scompact = zeros_ND<3, complex<PRISMATIC_FLOAT_PRECISION> >(
			{{pars.numberBeams, pars.imageSize[0] / 2, pars.imageSize[1] / 2}});
	pars.transmission = zeros_ND<3, complex<PRISMATIC_FLOAT_PRECISION> >(
			{{pars.pot.get_dimk(), pars.pot.get_dimj(), pars.pot.get_dimi()}});
	{
		auto p = pars.pot.begin();
		for (auto &j:pars.transmission)j = exp(i * pars.sigma * (*p++));
	}
}
~~~

`createStreamsAndPlans2`: create/initialize the CUDA streams and setup the cuFFT plans. There are two cuFFT plans: one that is for the FFT/IFFT as the plane wave(s) are propagated/transmitted through the sample, and then a "small" cuFFT plan for calculating the final FFT after the output wave has been subsetted. We set the relevant device with `cudaSetDevice` and then use `cudaStreamCreate` to initialize the CUDA stream. `cufftSetStream` is used to associate the cuFFT plan with the appropriate stream.

~~~c++
inline void createStreamsAndPlans2(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                  CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){
	// create CUDA streams
	const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;
	cuda_pars.streams 		    = new cudaStream_t[total_num_streams];
	cuda_pars.cufft_plans		= new cufftHandle[total_num_streams];
	cuda_pars.cufft_plans_small = new cufftHandle[total_num_streams];

	// batch parameters for cuFFT
	const int rank      = 2;
	int n[]             = {(int)pars.imageSize[0], (int)pars.imageSize[1]};
	const int howmany   = pars.meta.batch_size_GPU;
	int idist           = n[0]*n[1];
	int odist           = n[0]*n[1];
	int istride         = 1;
	int ostride         = 1;
	int *inembed        = n;
	int *onembed        = n;

	int n_small[]       = {(int)pars.qyInd.size(), (int)pars.qxInd.size()};
	int idist_small     = n_small[0]*n_small[1];
	int odist_small     = n_small[0]*n_small[1];
	int *inembed_small  = n_small;
	int *onembed_small  = n_small;

	// create cuFFT plans and CUDA streams
	for (auto j = 0; j < total_num_streams; ++j) {
		cudaSetDevice(j % pars.meta.NUM_GPUS);
		cudaErrchk(cudaStreamCreate(&cuda_pars.streams[j]));
		cufftErrchk(cufftPlanMany(&cuda_pars.cufft_plans[j], rank, n, inembed, istride, idist, onembed, ostride, odist, PRISM_CUFFT_PLAN_TYPE, howmany));
		cufftErrchk(cufftPlanMany(&cuda_pars.cufft_plans_small[j], rank, n_small, inembed_small, istride, idist_small, onembed_small, ostride, odist_small, PRISM_CUFFT_PLAN_TYPE, howmany));
		cufftErrchk(cufftSetStream(cuda_pars.cufft_plans[j], cuda_pars.streams[j]));
		cufftErrchk(cufftSetStream(cuda_pars.cufft_plans_small[j], cuda_pars.streams[j]));
	}
}
~~~

`allocatePinnedHostMemory_streaming2`: To copy data from the host to the device asynchronously, the source data must be in page-locked memory. Here we allocate such arrays using `cudaMallocHost`

~~~c++
inline void allocatePinnedHostMemory_streaming2(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                         CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){
	const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;

	// allocate pinned memory
	cuda_pars.Scompact_slice_ph = new std::complex<PRISMATIC_FLOAT_PRECISION>*[total_num_streams];
	for (auto s = 0; s < total_num_streams; ++s) {
		cudaErrchk(cudaMallocHost((void **) &cuda_pars.Scompact_slice_ph[s],
		                          pars.Scompact.get_dimj() * pars.Scompact.get_dimi() *
		                          sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>)));
	}
	cudaErrchk(cudaMallocHost((void **) &cuda_pars.trans_ph,      pars.transmission.size() * sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>)));
	cudaErrchk(cudaMallocHost((void **) &cuda_pars.prop_ph,       pars.prop.size()         * sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>)));
	cudaErrchk(cudaMallocHost((void **) &cuda_pars.qxInd_ph,      pars.qxInd.size()        * sizeof(size_t)));
	cudaErrchk(cudaMallocHost((void **) &cuda_pars.qyInd_ph,      pars.qyInd.size()        * sizeof(size_t)));
	cudaErrchk(cudaMallocHost((void **) &cuda_pars.beamsIndex_ph, pars.beamsIndex.size()   * sizeof(size_t)));
}
~~~

`copyToPinnedMemory_streaming2`: And now we copy the relevant memory into the pinned buffers. This is a host-to-host transfer.

~~~c++
inline void copyToPinnedMemory_streaming2(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                         CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){
	const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;

	// copy host memory to pinned
	for (auto s = 0; s < total_num_streams; ++s) {
		memset(cuda_pars.Scompact_slice_ph[s], 0, pars.Scompact.get_dimj() * pars.Scompact.get_dimi() *
		                                          sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>));
	}
	memcpy(cuda_pars.trans_ph,      &pars.transmission[0], pars.transmission.size() * sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>));
	memcpy(cuda_pars.prop_ph,       &pars.prop[0],         pars.prop.size()         * sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>));
	memcpy(cuda_pars.qxInd_ph,      &pars.qxInd[0],        pars.qxInd.size()        * sizeof(size_t));
	memcpy(cuda_pars.qyInd_ph,      &pars.qyInd[0],        pars.qyInd.size()        * sizeof(size_t));
	memcpy(cuda_pars.beamsIndex_ph, &pars.beamsIndex[0],   pars.beamsIndex.size()   * sizeof(size_t));
}
~~~

`allocateDeviceMemory_streaming2`: Now we allocate memory on the device with `cudaMalloc`. This includes read-only arrays being allocated once per GPU, and read/write arrays being allocated once per stream.

~~~c++
inline void allocateDeviceMemory_streaming2(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                           CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){
	const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;
	// pointers to read-only GPU memory (one copy per GPU)
	cuda_pars.prop_d       = new PRISM_CUDA_COMPLEX_FLOAT*[pars.meta.NUM_GPUS];
	cuda_pars.qxInd_d      = new size_t*[pars.meta.NUM_GPUS];
	cuda_pars.qyInd_d      = new size_t*[pars.meta.NUM_GPUS];
	cuda_pars.beamsIndex_d = new size_t*[pars.meta.NUM_GPUS];

	// pointers to read/write GPU memory (one per stream)
	cuda_pars.psi_ds       = new PRISM_CUDA_COMPLEX_FLOAT*[total_num_streams];
	cuda_pars.psi_small_ds = new PRISM_CUDA_COMPLEX_FLOAT*[total_num_streams];
	cuda_pars.trans_d      = new PRISM_CUDA_COMPLEX_FLOAT*[total_num_streams];

	// allocate memory on each GPU
	for (auto g = 0; g < pars.meta.NUM_GPUS; ++g) {
		cudaErrchk(cudaSetDevice(g));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.prop_d[g],       pars.prop.size()       * sizeof(PRISM_CUDA_COMPLEX_FLOAT)));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.qxInd_d[g],      pars.qxInd.size()      * sizeof(size_t)));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.qyInd_d[g],      pars.qyInd.size()      * sizeof(size_t)));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.beamsIndex_d[g], pars.beamsIndex.size() * sizeof(size_t)));
	}

	// allocate memory per stream and 0 it
	for (auto s = 0; s < total_num_streams; ++s) {
		cudaErrchk(cudaSetDevice(s % pars.meta.NUM_GPUS));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.trans_d[s],
		                      pars.imageSize[0]  *  pars.imageSize[1]    * sizeof(PRISM_CUDA_COMPLEX_FLOAT)));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.psi_ds[s],
		                      pars.meta.batch_size_GPU*pars.imageSize[0] * pars.imageSize[1] * sizeof(PRISM_CUDA_COMPLEX_FLOAT)));
		cudaErrchk(cudaMalloc((void **) &cuda_pars.psi_small_ds[s],
		                      pars.meta.batch_size_GPU*pars.qxInd.size() * pars.qyInd.size() * sizeof(PRISM_CUDA_COMPLEX_FLOAT)));
		cudaErrchk(cudaMemset(cuda_pars.psi_ds[s], 0,
		                      pars.meta.batch_size_GPU*pars.imageSize[0] * pars.imageSize[1] * sizeof(PRISM_CUDA_COMPLEX_FLOAT)));
		cudaErrchk(cudaMemset(cuda_pars.psi_small_ds[s], 0,
		                      pars.meta.batch_size_GPU*pars.qxInd.size() * pars.qyInd.size() * sizeof(PRISM_CUDA_COMPLEX_FLOAT)));
	}
}
~~~

`copyToDeviceMemory_streaming2`: Here we copy some arrays to the device. Note that although this is the streaming code, the only data that is streamed is that of the large 3D arrays, in this case the transmission function. Smaller data structures are still transferred once, and that is done here. The stream is incremented in between each copy simply because it can make this step slightly faster. At the end we synchronize to ensure that all of the copying is done.

~~~c++
inline void copyToDeviceMemory_streaming2(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                         CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){
const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;

// Copy memory to each GPU asynchronously from the pinned host memory spaces.
// The streams are laid out so that consecutive streams represent different GPUs. If we
// have more than one stream per GPU, then we want to interleave as much as possible
int stream_id = 0;
for (auto g = 0; g < pars.meta.NUM_GPUS; ++g) {
	stream_id = g;
	cudaErrchk(cudaSetDevice(g));

	stream_id = (stream_id + pars.meta.NUM_GPUS) % total_num_streams;
	cudaErrchk(cudaMemcpyAsync(cuda_pars.prop_d[g],
	                           &cuda_pars.prop_ph[0],
	                           pars.prop.size() * sizeof(std::complex<PRISMATIC_FLOAT_PRECISION>),
	                           cudaMemcpyHostToDevice,
	             				    cuda_pars.streams[stream_id]));

	stream_id = (stream_id + pars.meta.NUM_GPUS) % total_num_streams;
	cudaErrchk(cudaMemcpyAsync(cuda_pars.qxInd_d[g],
	                           &cuda_pars.qxInd_ph[0],
	                           pars.qxInd.size() * sizeof(size_t),
	                           cudaMemcpyHostToDevice,
	                           cuda_pars.streams[stream_id]));

	stream_id = (stream_id + pars.meta.NUM_GPUS) % total_num_streams;
	cudaErrchk(cudaMemcpyAsync(cuda_pars.qyInd_d[g],
	                           &cuda_pars.qyInd_ph[0],
	                           pars.qyInd.size() * sizeof(size_t),
	                           cudaMemcpyHostToDevice,
	                           cuda_pars.streams[stream_id]));

	stream_id = (stream_id + pars.meta.NUM_GPUS) % total_num_streams;
	cudaErrchk(cudaMemcpyAsync(cuda_pars.beamsIndex_d[g],
	                           &cuda_pars.beamsIndex_ph[0],
	                           pars.beamsIndex.size() * sizeof(size_t),
	                           cudaMemcpyHostToDevice,
	                           cuda_pars.streams[stream_id]));
}

// make sure transfers are complete
for (auto g = 0; g < pars.meta.NUM_GPUS; ++g) {
	cudaSetDevice(g);
	cudaDeviceSynchronize();
}
}
~~~

`launchWorkers_streaming`: This is very similar to the work loop from the projected potential section. The relevant arrays are passed to a worker thread which enters a while loop getting work from a `WorkDispatcher`, this time one that passing out jobs corresponding to plane waves to propagate. This uses batch FFTs, and the worker thread gets one batch of work from the dispatcher and then completes it, so the while loop only occurs once. Originally, only one plane wave was propagated at a time, but it was possible to query multiple jobs from the dispatcher. This has since been updated, but I left both versions there in case it is revisited in the future (i.e. for the case of batch size 1, it might be faster to ignore the batch FFT planning step).

~~~c++
void launchWorkers_streaming(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                    CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){

 // launch workers
const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;

// launch GPU work
vector<thread> workers_GPU;
workers_GPU.reserve(total_num_streams); // prevents multiple reallocations
int stream_count = 0;
const size_t PRISM_PRINT_FREQUENCY_BEAMS = max((size_t)1,pars.numberBeams / 10); // for printing status
WorkDispatcher dispatcher(0, pars.numberBeams); // create work dispatcher
for (auto t = 0; t < total_num_streams; ++t) {
	int GPU_num = stream_count % pars.meta.NUM_GPUS; // determine which GPU handles this job
	cudaSetDevice(GPU_num);
	cudaStream_t &current_stream = cuda_pars.streams[stream_count];
	// get pointers to the pre-copied arrays, making sure to get those on the current GPU
	PRISM_CUDA_COMPLEX_FLOAT *current_prop_d = cuda_pars.prop_d[GPU_num];
	size_t *current_qxInd_d                  = cuda_pars.qxInd_d[GPU_num];
	size_t *current_qyInd_d                  = cuda_pars.qyInd_d[GPU_num];
	size_t *current_beamsIndex               = cuda_pars.beamsIndex_d[GPU_num];

	// get pointers to per-stream arrays
	PRISM_CUDA_COMPLEX_FLOAT *current_trans_ds         = cuda_pars.trans_d[stream_count];
	PRISM_CUDA_COMPLEX_FLOAT *current_psi_ds           = cuda_pars.psi_ds[stream_count];
	PRISM_CUDA_COMPLEX_FLOAT *current_psi_small_ds     = cuda_pars.psi_small_ds[stream_count];
	cufftHandle &current_cufft_plan                    = cuda_pars.cufft_plans[stream_count];
	cufftHandle &current_cufft_plan_small              = cuda_pars.cufft_plans_small[stream_count];
	complex<PRISMATIC_FLOAT_PRECISION> *current_S_slice_ph = cuda_pars.Scompact_slice_ph[stream_count];

	workers_GPU.push_back(thread([&pars, current_trans_ds, current_prop_d, current_qxInd_d, current_qyInd_d, &dispatcher,
			                             current_psi_ds, current_psi_small_ds, &current_cufft_plan, &current_cufft_plan_small,
			                             current_S_slice_ph, current_beamsIndex, GPU_num, stream_count, &current_stream, &PRISM_PRINT_FREQUENCY_BEAMS, &cuda_pars]() {
		cudaErrchk(cudaSetDevice(GPU_num));

		// main work loop
		size_t currentBeam, stopBeam;
		currentBeam=stopBeam=0;
		while (dispatcher.getWork(currentBeam, stopBeam, pars.meta.batch_size_GPU)) { // get a batch of work
			while (currentBeam < stopBeam) {
				if (currentBeam % PRISM_PRINT_FREQUENCY_BEAMS < pars.meta.batch_size_GPU | currentBeam == 100){
					cout << "Computing Plane Wave #" << currentBeam << "/" << pars.numberBeams << endl;
				}
//			propagatePlaneWave_GPU_streaming(pars,
//			                                 current_trans_ds,
//			                                 trans_ph,
//			                                 current_psi_ds,
//			                                 current_psi_small_ds,
//				                             current_S_slice_ph,
//			                                 current_qyInd_d,
//			                                 current_qxInd_d,
//			                                 current_prop_d,
//			                                 current_beamsIndex,
//			                                 currentBeam,
//			                                 current_cufft_plan,
//			                                 current_cufft_plan_small,
//			                                 current_stream);
	propagatePlaneWave_GPU_streaming_batch(pars,
	                                       current_trans_ds,
	                                       cuda_pars.trans_ph,
	                                       current_psi_ds,
	                                       current_psi_small_ds,
	                                       current_S_slice_ph,
	                                       current_qyInd_d,
	                                       current_qxInd_d,
	                                       current_prop_d,
	                                       current_beamsIndex,
	                                       currentBeam,
	                                       stopBeam,
	                                       current_cufft_plan,
	                                       current_cufft_plan_small,
	                                       current_stream);
//						++currentBeam;
				currentBeam=stopBeam;
#ifdef PRISM_BUILDING_GUI
				pars.progressbar->signalScompactUpdate(currentBeam, pars.numberBeams);
#endif
			}
		}
		cout << "GPU worker on stream #" << stream_count << " of GPU #" << GPU_num << " finished\n";
	}));
	++stream_count;
}

if (pars.meta.also_do_CPU_work){

// launch CPU work
vector<thread> workers_CPU;
workers_CPU.reserve(pars.meta.NUM_THREADS); // prevents multiple reallocations
mutex fftw_plan_lock;
pars.meta.batch_size_CPU = min(pars.meta.batch_size_target_CPU, max((size_t)1, pars.numberBeams / pars.meta.NUM_THREADS));

// startup FFTW threads
PRISM_FFTW_INIT_THREADS();
PRISM_FFTW_PLAN_WITH_NTHREADS(pars.meta.NUM_THREADS);
for (auto t = 0; t < pars.meta.NUM_THREADS; ++t) {
	cout << "Launching thread #" << t << " to compute beams\n";
	workers_CPU.push_back(thread([&pars, &fftw_plan_lock, &dispatcher, &PRISM_PRINT_FREQUENCY_BEAMS]() {

		size_t currentBeam, stopBeam, early_CPU_stop;
		currentBeam=stopBeam=0;
		if (pars.meta.NUM_GPUS > 0){
			// if there are no GPUs, make sure to do all work on CPU
			early_CPU_stop = (size_t)std::max((PRISMATIC_FLOAT_PRECISION)0.0,pars.numberBeams - pars.meta.gpu_cpu_ratio*pars.meta.batch_size_CPU);
		} else {
			early_CPU_stop = pars.numberBeams;
		}

		if (dispatcher.getWork(currentBeam, stopBeam, pars.meta.batch_size_CPU, early_CPU_stop)) {
			// allocate array for psi just once per thread
			Array1D<complex<PRISMATIC_FLOAT_PRECISION> > psi_stack = zeros_ND<1, complex<PRISMATIC_FLOAT_PRECISION> >(
					{{pars.imageSize[0]*pars.imageSize[1]*pars.meta.batch_size_CPU}});

			// setup batch FFTW parameters
			const int rank    = 2;
			int n[]           = {(int)pars.imageSize[0], (int)pars.imageSize[1]};
			const int howmany = pars.meta.batch_size_CPU;
			int idist         = n[0]*n[1];
			int odist         = n[0]*n[1];
			int istride       = 1;
			int ostride       = 1;
			int *inembed      = n;
			int *onembed      = n;

			// create FFTW plans
			unique_lock<mutex> gatekeeper(fftw_plan_lock);
			PRISM_FFTW_PLAN plan_forward = PRISM_FFTW_PLAN_DFT_BATCH(rank, n, howmany,
			                                                         reinterpret_cast<PRISM_FFTW_COMPLEX *>(&psi_stack[0]), inembed,
			                                                         istride, idist,
			                                                         reinterpret_cast<PRISM_FFTW_COMPLEX *>(&psi_stack[0]), onembed,
			                                                         ostride, odist,
			                                                         FFTW_FORWARD, FFTW_MEASURE);
			PRISM_FFTW_PLAN plan_inverse = PRISM_FFTW_PLAN_DFT_BATCH(rank, n, howmany,
			                                                         reinterpret_cast<PRISM_FFTW_COMPLEX *>(&psi_stack[0]), inembed,
			                                                         istride, idist,
			                                                         reinterpret_cast<PRISM_FFTW_COMPLEX *>(&psi_stack[0]), onembed,
			                                                         ostride, odist,
			                                                         FFTW_BACKWARD, FFTW_MEASURE);
			gatekeeper.unlock(); // unlock it so we only block as long as necessary to deal with plans

			// main work loop
			do { // synchronously get work assignment
				while (currentBeam < stopBeam) {
					if (currentBeam % PRISM_PRINT_FREQUENCY_BEAMS < pars.meta.batch_size_CPU | currentBeam == 100){
						cout << "Computing Plane Wave #" << currentBeam << "/" << pars.numberBeams << endl;
					}
					// re-zero psi each iteration
					memset((void *) &psi_stack[0], 0, psi_stack.size() * sizeof(complex<PRISMATIC_FLOAT_PRECISION>));
//								propagatePlaneWave_CPU(pars, currentBeam, psi, plan_forward, plan_inverse, fftw_plan_lock);
					propagatePlaneWave_CPU_batch(pars, currentBeam, stopBeam, psi_stack, plan_forward, plan_inverse, fftw_plan_lock);
#ifdef PRISM_BUILDING_GUI
					pars.progressbar->signalScompactUpdate(currentBeam, pars.numberBeams);
#endif
					currentBeam = stopBeam;
//								++currentBeam;
				}
				if (currentBeam >= early_CPU_stop) break;
			} while (dispatcher.getWork(currentBeam, stopBeam, pars.meta.batch_size_CPU, early_CPU_stop));
			// clean up
			gatekeeper.lock();
			PRISM_FFTW_DESTROY_PLAN(plan_forward);
			PRISM_FFTW_DESTROY_PLAN(plan_inverse);
			gatekeeper.unlock();
		}
	}));
}
for (auto &t:workers_CPU)t.join();
PRISM_FFTW_CLEANUP_THREADS();
}
for (auto &t:workers_GPU)t.join();
}
~~~

The main function within the worker threads is `propagatePlaneWave_GPU_streaming_batch`, which contains our first kernel invocation, which are the function calls with the "\<\<\<  \>\>\>" syntax. We'll look at the details of the CUDA kernel in a second, but conceptually this function is doing the same thing as a multislice simulation: alternatingly FFT/IFFT the current wave function and multiply it element-wise with either the transmission or propagation function. There is also a division by the array size to account for the overall scaling factor applied when taking a forward/backward FFT (cuFFT is unnormalized).

`propagatePlaneWave_GPU_streaming_batch`:

~~~ c++
void propagatePlaneWave_GPU_streaming_batch(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                                            PRISM_CUDA_COMPLEX_FLOAT* trans_d,
                                            const std::complex<PRISMATIC_FLOAT_PRECISION> *trans_ph,
                                            PRISM_CUDA_COMPLEX_FLOAT* psi_d,
                                            PRISM_CUDA_COMPLEX_FLOAT* psi_small_d,                                     complex<PRISMATIC_FLOAT_PRECISION>* Scompact_slice_ph,
const size_t* qyInd_d,
const size_t* qxInd_d,
                                            const PRISM_CUDA_COMPLEX_FLOAT* prop_d,
                                            const size_t* beamsIndex,
                                            const size_t beamNumber,
                                            const size_t stopBeam,
                                            const cufftHandle& plan,
                                            const cufftHandle& plan_small,
                                            cudaStream_t& stream){
	// In this version, each slice of the transmission matrix is streamed to the device

	const size_t psi_size        = pars.imageSize[0] * pars.imageSize[1];
	const size_t psi_small_size = pars.qxInd.size() * pars.qyInd.size();
	for (auto batch_idx = 0; batch_idx < (stopBeam-beamNumber); ++batch_idx) {
		// initialize psi -- for PRISM this is just a delta function in Fourier space located depending on which plane wave it is
		initializePsi_oneNonzero<<< (psi_size - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream>>>(psi_d + batch_idx*psi_size, psi_size, pars.beamsIndex[beamNumber + batch_idx]);
	}

	for (auto planeNum = 0; planeNum < pars.numPlanes ; ++planeNum) {
		cudaErrchk(cudaMemcpyAsync(trans_d, &trans_ph[planeNum*psi_size], psi_size * sizeof(PRISM_CUDA_COMPLEX_FLOAT), cudaMemcpyHostToDevice, stream));
		cufftErrchk(PRISM_CUFFT_EXECUTE(plan, &psi_d[0], &psi_d[0], CUFFT_INVERSE));
		for (auto batch_idx = 0; batch_idx < (stopBeam-beamNumber); ++batch_idx) {
			multiply_cx <<< (psi_size - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream >>>
					(psi_d + batch_idx*psi_size, trans_d, psi_size); // transmit
			divide_inplace <<< (psi_size - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream >>>
					(psi_d + batch_idx*psi_size, PRISM_MAKE_CU_COMPLEX(psi_size, 0), psi_size); // normalize the FFT
		}
		cufftErrchk(PRISM_CUFFT_EXECUTE(plan, &psi_d[0], &psi_d[0], CUFFT_FORWARD));
		for (auto batch_idx = 0; batch_idx < (stopBeam-beamNumber); ++batch_idx) {
			multiply_cx <<< (psi_size - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream >>>
					(psi_d + batch_idx*psi_size, prop_d, psi_size); // propagate
		}
	}

	for (auto batch_idx = 0; batch_idx < (stopBeam-beamNumber); ++batch_idx) {
		// take relevant subset of the full array
		array_subset <<< (pars.qyInd.size() * pars.qxInd.size() - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0,
				stream >>> (psi_d + batch_idx*psi_size, psi_small_d + batch_idx*psi_small_size, qyInd_d, qxInd_d, pars.imageSize[1], pars.qyInd.size(), pars.qxInd.size());
	}

	// final FFT
	PRISM_CUFFT_EXECUTE(plan_small,&psi_small_d[0], &psi_small_d[0], CUFFT_INVERSE);
	for (auto batch_idx = 0; batch_idx < (stopBeam-beamNumber); ++batch_idx) {
	divide_inplace<<<(psi_small_size-1) / BLOCK_SIZE1D + 1,BLOCK_SIZE1D, 0, stream>>>
			(psi_small_d + batch_idx*psi_small_size, PRISM_MAKE_CU_COMPLEX(psi_small_size, 0),psi_small_size); // normalize the FFT
		}

	// copy the result
	for (auto batch_idx = 0; batch_idx < (stopBeam-beamNumber); ++batch_idx) {
	cudaErrchk(cudaMemcpyAsync(Scompact_slice_ph,&psi_small_d[batch_idx*psi_small_size],psi_small_size * sizeof(PRISM_CUDA_COMPLEX_FLOAT),cudaMemcpyDeviceToHost,stream));
	cudaStreamSynchronize(stream);
	memcpy(&pars.Scompact[(beamNumber + batch_idx) * pars.Scompact.get_dimj() * pars.Scompact.get_dimi()], &Scompact_slice_ph[0], psi_small_size * sizeof(PRISM_CUDA_COMPLEX_FLOAT));
		}
}
~~~

The `cudaMemcpyAsync` call at the beginning of the loop over `pars.numPlanes` is where the data streaming functionality is implemented. It's important to note that all of the kernel calls in this function use the same stream. If they did not, there would be no guarantee that the call to `cudaMemcpyAsync` is completed before subsequent kernels are called, which would be a race condition.

Initializing the probe for PRISM just requires setting a single Fourier component to 1, and the rest to 0. If you aren't familiar with CUDA, there are lots of resources online explaining the various relevant syntaxes. The basic idea is that in places where you would normally use a loop, you instead have a large number of threads that each perform the equivalent work of a single loop iteration. Each thread is aware of its indices in the threadblock and grid, so you first compute the thread's overall offset and then peform operations using logic based upon that.

~~~ c++
__global__ void initializePsi_oneNonzero(cuFloatComplex *psi_d, const size_t N, const size_t beamLoc){
	int idx = threadIdx.x + blockDim.x*blockIdx.x;
	if (idx < N) {
		psi_d[idx] = (idx == beamLoc) ? make_cuFloatComplex(1,0):make_cuFloatComplex(0,0);
	}
}
~~~

The element-wise arithmetic kernels are super trivial. Even if the underlying array is 2D for this kind of kernel I just treat it as 1D as if it were flattened.

~~~ c++
__global__ void divide_inplace(cuFloatComplex* arr,
                               const cuFloatComplex val,
                               const size_t N){
	int idx = threadIdx.x + blockDim.x*blockIdx.x;
	if (idx < N) {
		arr[idx] = cuCdivf(arr[idx], val);
	}
}

// multiply two complex arrays
__global__ void multiply_cx(cuFloatComplex* arr,
                            const cuFloatComplex* other,
                            const size_t N){
	int idx = threadIdx.x + blockDim.x*blockIdx.x;
	if (idx < N) {
		arr[idx] = cuCmulf(arr[idx], other[idx]);
	}
}

~~~

The macro `PRISM_CUFFT_EXECUTE` is an alias for either `cufftExecC2C` or `cufftExecZ2Z` depending on whether *Prismatic* has been compiled for single or double precision.

Once the wave function has been propagated through the entire sample, there is one last kernel to crop the probe based upon the PRISM interpolation factor, then a final IFFT on the subsetted array is taken, which forms the calculated slice of the compact S-matrix. This is then asynchronously streamed back to the page-locked output slice buffer. The stream is then synchronized to guarantee this memory transfer completes, and then there is a final host-to-host memory transfer to copy the result to the compact S-matrix inside of `Parameters`. This effectively completes the task.

`cleanupMemory2`: free all of the memory on the device and the host once all jobs are completed.

~~~c++
inline void cleanupMemory2(Parameters<PRISMATIC_FLOAT_PRECISION> &pars,
                          CudaParameters<PRISMATIC_FLOAT_PRECISION> &cuda_pars){

	// free host and device memory
	const int total_num_streams = pars.meta.NUM_GPUS * pars.meta.NUM_STREAMS_PER_GPU;
	for (auto g = 0; g < pars.meta.NUM_GPUS; ++g) {
		cudaErrchk(cudaSetDevice(g));
		cudaErrchk(cudaFree(cuda_pars.trans_d[g]));
		cudaErrchk(cudaFree(cuda_pars.prop_d[g]));
		cudaErrchk(cudaFree(cuda_pars.qxInd_d[g]));
		cudaErrchk(cudaFree(cuda_pars.qyInd_d[g]));
		cudaErrchk(cudaFree(cuda_pars.beamsIndex_d[g]));
	}

	for (auto s = 0; s < total_num_streams; ++s) {
		cudaErrchk(cudaSetDevice(s % pars.meta.NUM_GPUS));
		cudaErrchk(cudaFree(cuda_pars.psi_ds[s]));
		cudaErrchk(cudaFree(cuda_pars.psi_small_ds[s]));
		cufftErrchk(cufftDestroy(cuda_pars.cufft_plans[s]));
		cufftErrchk(cufftDestroy(cuda_pars.cufft_plans_small[s]));
	}

	// free pinned memory
	for (auto s = 0; s < total_num_streams; ++s) {
		cudaErrchk(cudaFreeHost(cuda_pars.Scompact_slice_ph[s]));
	}
	cudaErrchk(cudaFreeHost(cuda_pars.trans_ph));
	cudaErrchk(cudaFreeHost(cuda_pars.prop_ph));
	cudaErrchk(cudaFreeHost(cuda_pars.qxInd_ph));
	cudaErrchk(cudaFreeHost(cuda_pars.qyInd_ph));
	cudaErrchk(cudaFreeHost(cuda_pars.beamsIndex_ph));


	// destroy CUDA streams
	for (auto j = 0; j < total_num_streams; ++j){
		cudaSetDevice(j % pars.meta.NUM_GPUS);
		cudaErrchk(cudaStreamDestroy(cuda_pars.streams[j]));
	}

	for (auto g = 0; g < pars.meta.NUM_GPUS; ++g){
		cudaErrchk(cudaSetDevice(g));
		cudaErrchk(cudaDeviceReset());
	}

	delete[] cuda_pars.streams;
	delete[] cuda_pars.cufft_plans;
	delete[] cuda_pars.cufft_plans_small;
	delete[] cuda_pars.trans_d;
	delete[] cuda_pars.prop_d;
	delete[] cuda_pars.qxInd_d;
	delete[] cuda_pars.qyInd_d;
	delete[] cuda_pars.beamsIndex_d;
	delete[] cuda_pars.psi_ds;
	delete[] cuda_pars.psi_small_ds;
	delete[] cuda_pars.Scompact_slice_ph;
}
~~~

### Compute PRISM Output

The last step of PRISM is to compute the output wave for each probe position. The top-level portion of the PRISM03_calcOutput step looks very similar to the second step and I won't go through the details as before. The point is there are many sub functions that setup coordinates and arrays, and then the "real work" occurs in `buildPRISMOutput`, which is another configured function pointer that represents one of the various ways to populate the PRISM output.

~~~ c++
void PRISM03_calcOutput(Parameters<PRISMATIC_FLOAT_PRECISION> &pars) {
	// compute final image

	cout << "Entering PRISM03_calcOutput" << endl;

	// setup necessary coordinates
	setupCoordinates_2(pars);

	// setup angles of detector and image sizes
	setupDetector(pars);

	// setup coordinates and indices for the beams
	setupBeams_2(pars);

	// setup Fourier coordinates for the S-matrix
	setupFourierCoordinates(pars);

	// initialize the output to the correct size for the output mode
	createStack_integrate(pars);

	// perform some necessary setup transformations of the data
	transformIndices(pars);

	// initialize/compute the probes
	initializeProbes(pars);

	// compute the final PRISM output
	buildPRISMOutput(pars);
}
~~~

where `buildPRISMOutput` might point to `buildPRISMOutput_GPU_streaming`. Just as in the calculation of the compact S-matrix, there are a series of steps for allocating/copying to pinned/device memory. This is followed by launch of the workers, and lastly cleanup. These kinds of programming patterns are repeated all throughout *Prismatic* -- there's really not that much craziness going on.

~~~c++	
void buildPRISMOutput_GPU_streaming(Parameters<PRISMATIC_FLOAT_PRECISION> &pars){
#ifdef PRISM_BUILDING_GUI
	pars.progressbar->signalDescriptionMessage("Computing final output (PRISM)");
#endif
	CudaParameters<PRISMATIC_FLOAT_PRECISION> cuda_pars;
	// construct the PRISM output array using GPUs

	// create CUDA streams and cuFFT plans
	createStreamsAndPlans3(pars, cuda_pars);

	// allocate pinned memory
	allocatePinnedHostMemory_streaming3(pars, cuda_pars);

	// copy data to pinned buffers
	copyToPinnedMemory_streaming3(pars, cuda_pars);

	// allocate memory on the GPUs
	allocateDeviceMemory_streaming3(pars, cuda_pars);

	// copy memory to GPUs
	copyToGPUMemory_streaming3(pars, cuda_pars);

	// launch GPU and CPU workers
	launchWorkers_streaming3(pars, cuda_pars);

	// free memory on the host/device
	cleanupMemory3(pars, cuda_pars);
}
~~~

Most of the launch workers function is similar to before, but I will point out that now the work ID passed back by the `WorkDispatcher` actually corresponds to an X,Y probe position, so there is additional logic to convert that.

~~~ c++
// from within launchWorkers_streaming3
// ...
// ...
// ...
size_t Nstart, Nstop, ay, ax;
Nstart=Nstop=0;
while (dispatcher.getWork(Nstart, Nstop)) { // synchronously get work assignment
	while (Nstart < Nstop) {
		if (Nstart % PRISM_PRINT_FREQUENCY_PROBES == 0 | Nstart == 100){
			cout << "Computing Probe Position #" << Nstart << "/" << pars.xp.size() * pars.yp.size() << endl;
		}
		ay = Nstart / pars.xp.size();
		ax = Nstart % pars.xp.size();
		buildSignal_GPU_streaming(pars, ay, ax, current_permuted_Scompact_ds, cuda_pars.permuted_Scompact_ph,
		                          current_PsiProbeInit_d, current_qxaReduce_d, current_qyaReduce_d,
		                          current_yBeams_d, current_xBeams_d, current_alphaInd_d, current_psi_ds,
		                          current_phaseCoeffs_ds, current_psi_intensity_ds, current_y_ds,
		                          current_x_ds, current_output_ph, current_integratedOutput_ds, current_cufft_plan, current_stream,  cuda_pars );
#ifdef PRISM_BUILDING_GUI
		pars.progressbar->signalOutputUpdate(Nstart, pars.xp.size() * pars.yp.size());
#endif
		++Nstart;
	}
}
~~~

Okay, the last big thing is the GPU code for constructing the output at the probe position (`ax`,`ay`). A lot goes on so I'll go step by step

~~~ c++
void buildSignal_GPU_streaming(Parameters<PRISMATIC_FLOAT_PRECISION>&  pars,
                               const size_t& ay,
                               const size_t& ax,
                               PRISM_CUDA_COMPLEX_FLOAT *permuted_Scompact_ds,
                               const std::complex<PRISMATIC_FLOAT_PRECISION> *permuted_Scompact_ph,
                               const PRISM_CUDA_COMPLEX_FLOAT *PsiProbeInit_d,
                               const PRISMATIC_FLOAT_PRECISION *qxaReduce_d,
                               const PRISMATIC_FLOAT_PRECISION *qyaReduce_d,
                               const size_t *yBeams_d,
                               const size_t *xBeams_d,
                               const PRISMATIC_FLOAT_PRECISION *alphaInd_d,
                               PRISM_CUDA_COMPLEX_FLOAT *psi_ds,
                               PRISM_CUDA_COMPLEX_FLOAT *phaseCoeffs_ds,
                               PRISMATIC_FLOAT_PRECISION *psi_intensity_ds,
                               long  *y_ds,
                               long  *x_ds,
                               PRISMATIC_FLOAT_PRECISION *output_ph,
                               PRISMATIC_FLOAT_PRECISION *integratedOutput_ds,
                               const cufftHandle &cufft_plan,
                               const cudaStream_t& stream,
                               CudaParameters<PRISMATIC_FLOAT_PRECISION>& cuda_pars){

    // the coordinates y and x of the output image phi map to z and y of the permuted S compact matrix
    const PRISMATIC_FLOAT_PRECISION yp = pars.yp[ay];
    const PRISMATIC_FLOAT_PRECISION xp = pars.xp[ax];
    const size_t psi_size = pars.imageSizeReduce[0] * pars.imageSizeReduce[1];
    shiftIndices <<<(pars.imageSizeReduce[0] - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream>>> (
            y_ds, std::round(yp / pars.pixelSizeOutput[0]),pars.imageSize[0], pars.imageSizeReduce[0]);

    shiftIndices <<<(pars.imageSizeReduce[1] - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream>>> (
            x_ds, std::round(xp / pars.pixelSizeOutput[1]), pars.imageSize[1], pars.imageSizeReduce[1]);

    computePhaseCoeffs <<<(pars.numberBeams - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream>>>(
            phaseCoeffs_ds, PsiProbeInit_d, qyaReduce_d, qxaReduce_d,
            yBeams_d, xBeams_d, yp, xp, pars.yTiltShift, pars.xTiltShift, pars.imageSizeReduce[1], pars.numberBeams);

~~~

The first step is to shift the coordinates of the S-Matrix subset to be centered on the relevant output position:

~~~ c++
// from utility.cu
__global__ void shiftIndices(long* vec_out, const long by, const long imageSize, const long N){
    long idx = threadIdx.x + blockDim.x * blockIdx.x;
    if (idx < N){
        vec_out[idx] = (imageSize + ((idx - N/2 + by) % imageSize)) % imageSize;
    }
}

~~~

The modular division operation (%) is to deal with wraparound, and because modular division in C++ can return negative values I add an outer addition and second modular operation, which is an idiom for guaranteeing a positive result.

Next, for the streaming version, we have to copy the relevant subset of the compact S-Matrix. This can be done with at most 4 strided memory copies depending on whether or not the array subset wraps around in the X and/or Y directions.

~~~ c++
// Copy the relevant portion of the Scompact matrix. This can be accomplished with ideally one but at most 4 strided 3-D memory copies
// depending on whether or not the coordinates wrap around.
long x1,y1;
y1 = pars.yVec[0] + std::round(yp / (PRISMATIC_FLOAT_PRECISION)pars.pixelSizeOutput[0]);
x1 = pars.xVec[0] + std::round(xp / (PRISMATIC_FLOAT_PRECISION)pars.pixelSizeOutput[1]);


// determine where in the coordinate list wrap-around occurs (if at all)
long xsplit, ysplit, nx2, ny2, xstart1, xstart2, ystart1, ystart2;
xsplit = (x1 < 0) ? -x1 : (x1 + pars.xVec.size() > pars.Scompact.get_dimi()) ? pars.Scompact.get_dimi() - x1 : pars.xVec.size();
ysplit = (y1 < 0) ? -y1 : (y1 + pars.yVec.size() > pars.Scompact.get_dimj()) ? pars.Scompact.get_dimj() - y1 : pars.yVec.size();

nx2 = pars.xVec.size() - xsplit;
ny2 = pars.yVec.size() - ysplit;

xstart1 = ((long) pars.imageSizeOutput[1] + (x1 % (long) pars.imageSizeOutput[1])) %
           (long) pars.imageSizeOutput[1];
xstart2 = ((long) pars.imageSizeOutput[1] + (x1 + xsplit % (long) pars.imageSizeOutput[1])) %
           (long) pars.imageSizeOutput[1];
ystart1 = ((long) pars.imageSizeOutput[0] + (y1 % (long) pars.imageSizeOutput[0])) %
           (long) pars.imageSizeOutput[0];
ystart2 = ((long) pars.imageSizeOutput[0] + (y1 + ysplit % (long) pars.imageSizeOutput[0])) %
           (long) pars.imageSizeOutput[0];

cudaErrchk(cudaMemcpy2DAsync(permuted_Scompact_ds,
                             pars.imageSizeReduce[1] * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                             &permuted_Scompact_ph[ystart1 * pars.numberBeams * pars.Scompact.get_dimi() +
                                                   xstart1 * pars.numberBeams],
                             pars.Scompact.get_dimi() * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT), // corresponds to stride between permuted Scompact elements in k-direction
                             xsplit * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                             ysplit,
                             cudaMemcpyHostToDevice,
                             stream));
if (nx2 > 0 ) {
    cudaErrchk(cudaMemcpy2DAsync(&permuted_Scompact_ds[xsplit * pars.numberBeams],
                                 pars.imageSizeReduce[1] * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                                 &permuted_Scompact_ph[ystart1 * pars.numberBeams * pars.Scompact.get_dimi() +
                                                       xstart2 * pars.numberBeams],
                                 pars.Scompact.get_dimi() * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT), // corresponds to stride between permuted Scompact elements in k-direction
                                 nx2 * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                                 ysplit,
                                 cudaMemcpyHostToDevice,
                                 stream));
}
if (ny2 > 0 ) {
    cudaErrchk(cudaMemcpy2DAsync(&permuted_Scompact_ds[ysplit * pars.imageSizeReduce[1] * pars.numberBeams],
                                 pars.imageSizeReduce[1] * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                                 &permuted_Scompact_ph[ystart2 * pars.numberBeams * pars.Scompact.get_dimi() +
                                                       xstart1 * pars.numberBeams],
                                 pars.Scompact.get_dimi() * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT), // corresponds to stride between permuted Scompact elements in k-direction
                                 xsplit * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                                 ny2,
                                 cudaMemcpyHostToDevice,
                                 stream));
}
if (ny2 > 0 & nx2 > 0) {
    cudaErrchk(cudaMemcpy2DAsync(&permuted_Scompact_ds[ysplit * pars.imageSizeReduce[1] * pars.numberBeams +
                                                       xsplit * pars.numberBeams],
                                 pars.imageSizeReduce[1] * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                                 &permuted_Scompact_ph[ystart2 * pars.numberBeams * pars.Scompact.get_dimi() +
                                                       xstart2 * pars.numberBeams],
                                 pars.Scompact.get_dimi() * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT), // corresponds to stride between permuted Scompact elements in k-direction
                                 nx2 * pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT),
                                 ny2,
                                 cudaMemcpyHostToDevice,
                                 stream));
}

~~~

Now we choose a launch configuration. This is discussed in detail in the PRISM algorithm paper, but the strategy is to choose a launch configuration that is preferably large along the direction of the plane-waves in the compact S-Matrix, which is the x-direction. Specifically $BlockSize_x$ is chosen to be the largest power of two less than the number of beams, or the maximum number of threads per block. This way there are usually enough threads to do the work, but you also get the advantage of having threads read multiple values before reducing, which is an optimization technique. So first there is some code to query the device properties and determine what parameters we have to work with.

~~~ c++
// The data is now copied and we can proceed with the actual calculation

// re-center the indices
resetIndices <<<(pars.imageSizeReduce[0] - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream>>> (
        y_ds, pars.imageSizeReduce[0]);

resetIndices <<<(pars.imageSizeReduce[1] - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream>>> (
        x_ds, pars.imageSizeReduce[1]);

// Choose a good launch configuration
// Heuristically use 2^p / 2 as the block size where p is the first power of 2 greater than the number of elements to work on.
// This balances having enough work per thread and enough blocks without having so many blocks that the shared memory doesn't last long

size_t p = getNextPower2(pars.numberBeams);
const size_t BlockSize_numBeams = min((size_t)pars.deviceProperties.maxThreadsPerBlock,(size_t)std::max(1.0, pow(2,p) / 2));

// Determine maximum threads per streaming multiprocessor based on the compute capability of the device
size_t max_threads_per_sm;
if (pars.deviceProperties.major > 3){
    max_threads_per_sm = 2048;
} else if (pars.deviceProperties.major > 2) {
    max_threads_per_sm = 1536;
} else {
    max_threads_per_sm = pars.deviceProperties.minor == 0 ? 768 : 1024;
}

// Estimate max number of simultaneous blocks per streaming multiprocessor
const size_t max_blocks_per_sm = std::min((size_t)32, max_threads_per_sm / BlockSize_numBeams);

// We find providing around 3 times as many blocks as the estimated maximum provides good performance
const size_t target_blocks_per_sm = max_blocks_per_sm * 3;
const size_t total_blocks         = target_blocks_per_sm * pars.deviceProperties.multiProcessorCount;

// Determine amount of shared memory needed
const unsigned long smem = pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT);

~~~

For rare simulation cases where there are very few beams, we will increase the block dimensions in X and Y, but most of the time there will be sufficient numbers of beams and the blocks will be effectively 1D. The actual reduction kernel we are then invoking is `scaleReduceS`. If the blockSize used for the function is visible at compile time, then the compiler can perform optimizations such as loop unrolling. However, we are determining the blockSize at runtime - but we can get around this by using a switch statement with a templated kernel. The compiler will see and separately optimize every version of the kernel, and then invoke the relevant one at runtime. There is both a 1-parameter and 2-parameter version of `scaleReduceS`, the latter being for the case where the blockSize is greater than 1 for Y/Z.

~~~ c++
if (BlockSize_numBeams >= 64) {

    const PRISMATIC_FLOAT_PRECISION aspect_ratio = (PRISMATIC_FLOAT_PRECISION)pars.imageSizeReduce[1] / (PRISMATIC_FLOAT_PRECISION)pars.imageSizeReduce[0];
    const size_t GridSizeZ = std::floor(sqrt(total_blocks / aspect_ratio));
    const size_t GridSizeY = aspect_ratio * GridSizeZ;
    dim3 grid(1, GridSizeY, GridSizeZ);
    dim3 block(BlockSize_numBeams, 1, 1);
//      // Launch kernel. Block size must be visible at compile time so we use a switch statement
    switch (BlockSize_numBeams) {
        case 1024 :
            scaleReduceS<1024> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 512 :
            scaleReduceS<512> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 256 :
            scaleReduceS<256> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 128 :
            scaleReduceS<128> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 64 :
            scaleReduceS<64> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 32 :
            scaleReduceS<32> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 16 :
            scaleReduceS<16> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 8 :
            scaleReduceS<8> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 4 :
            scaleReduceS<4> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        default :
            scaleReduceS<2> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
    }
} else {
    const size_t BlockSize_alongArray = 512 / BlockSize_numBeams;
    const size_t GridSize_alongArray = total_blocks;
    dim3 grid(1, GridSize_alongArray, 1);
    dim3 block(BlockSize_numBeams, BlockSize_alongArray, 1);
    // Determine amount of shared memory needed
    const unsigned long smem = pars.numberBeams * sizeof(PRISM_CUDA_COMPLEX_FLOAT);

    // Launch kernel. Block size must be visible at compile time so we use a switch statement
    switch (BlockSize_numBeams) {
        case 1024 :
            scaleReduceS<1024, 1> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 512 :
            scaleReduceS<512, 1> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 256 :
            scaleReduceS<256, 2> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 128 :
            scaleReduceS<128, 4> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 64 :
            scaleReduceS<64, 8> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 32 :
            scaleReduceS<32, 16> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 16 :
            scaleReduceS<16, 32> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 8 :
            scaleReduceS<8, 64> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        case 4 :
            scaleReduceS<4, 128> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
        default :
            scaleReduceS<1, 512> << < grid, block, smem, stream >> > (
                    permuted_Scompact_ds, phaseCoeffs_ds, psi_ds, y_ds, x_ds, pars.numberBeams, pars.imageSizeReduce[0],
                    pars.imageSizeReduce[1], pars.imageSizeReduce[0], pars.imageSizeReduce[1]);break;
    }
}

~~~

Let's look at `scaleReduceS`, as it is one of the most important parts of *Prismatic*.

~~~ c++
template <size_t BlockSizeX>
__global__ void scaleReduceS(const cuFloatComplex *permuted_Scompact_d,
                             const cuFloatComplex *phaseCoeffs_ds,
                             cuFloatComplex *psi_ds,
                             const long *z_ds,
                             const long* y_ds,
                             const size_t numberBeams,
                             const size_t dimk_S,
                             const size_t dimj_S,
                             const size_t dimj_psi,
                             const size_t dimi_psi) {
    // This code is heavily modeled after Mark Harris's presentation on optimized parallel reduction
    // http://developer.download.nvidia.com/compute/cuda/1.1-Beta/x86_website/projects/reduction/doc/reduction.pdf

    // shared memory
    __shared__ cuFloatComplex scaled_values[BlockSizeX]; // for holding the values to reduce
    extern __shared__ cuFloatComplex coeff_cache []; // cache the coefficients to prevent repeated global reads

    // for the permuted Scompact matrix, the x direction runs along the number of beams, leaving y and z to represent the
    //  2D array of reduced values in psi
    int idx = threadIdx.x + blockDim.x * blockIdx.x;
    int y   = threadIdx.y + blockDim.y * blockIdx.y;
    int z   = threadIdx.z + blockDim.z * blockIdx.z;

    // determine grid size for stepping through the array
    int gridSizeY = gridDim.y * blockDim.y;
    int gridSizeZ = gridDim.z * blockDim.z;

    // guarantee the shared memory is initialized to 0 so we can accumulate without bounds checking
    scaled_values[threadIdx.x] = make_cuFloatComplex(0,0);
    __syncthreads();

    // read the coefficients into shared memory once
    size_t offset_phase_idx = 0;
    while (offset_phase_idx < numberBeams){
        if (idx + offset_phase_idx < numberBeams){
            coeff_cache[idx + offset_phase_idx] = phaseCoeffs_ds[idx + offset_phase_idx];
        }
        offset_phase_idx += BlockSizeX;
    }
    __syncthreads();

//      // each block processes several reductions strided by the grid size
    int y_saved = y;
    while (z < dimj_psi){
        y=y_saved; // reset y
        while(y < dimi_psi){
            //   read in first values
            if (idx < numberBeams) {
                scaled_values[idx] = cuCmulf(permuted_Scompact_d[z_ds[z]*numberBeams*dimj_S + y_ds[y]*numberBeams + idx],
                                             coeff_cache[idx]);
                __syncthreads();
            }

//       step through global memory accumulating until values have been reduced to BlockSizeX elements in shared memory
            size_t offset = BlockSizeX;
            while (offset < numberBeams){
                if (idx + offset < numberBeams){
                    scaled_values[idx] = cuCaddf(scaled_values[idx],
                                                 cuCmulf( permuted_Scompact_d[z_ds[z]*numberBeams*dimj_S + y_ds[y]*numberBeams + idx + offset],
                                                          coeff_cache[idx + offset]));
                }
                offset += BlockSizeX;
                __syncthreads();
            }

            // At this point we have exactly BlockSizeX elements to reduce from shared memory which we will add by recursively
            // dividing the array in half

            // Take advantage of templates. Because BlockSizeX is passed at compile time, all of these comparisons are also
            // evaluated at compile time
            if (BlockSizeX >= 1024){
                if (idx < 512){
                    scaled_values[idx] = cuCaddf(scaled_values[idx], scaled_values[idx + 512]);
                }
                __syncthreads();
            }

            if (BlockSizeX >= 512){
                if (idx < 256){
                    scaled_values[idx] = cuCaddf(scaled_values[idx], scaled_values[idx + 256]);
                }
                __syncthreads();
            }

            if (BlockSizeX >= 256){
                if (idx < 128){
                    scaled_values[idx] = cuCaddf(scaled_values[idx], scaled_values[idx + 128]);
                }
                __syncthreads();
            }

            if (BlockSizeX >= 128){
                if (idx < 64){
                    scaled_values[idx] = cuCaddf(scaled_values[idx], scaled_values[idx + 64]);
                }
                __syncthreads();
            }

            // use a special optimization for the last reductions
            if (idx < 32 & BlockSizeX <= numberBeams){
                warpReduce_cx<BlockSizeX>(scaled_values, idx);

            } else {
                warpReduce_cx<1>(scaled_values, idx);
            }

            // write out the result
            if (idx == 0)psi_ds[z*dimi_psi + y] = scaled_values[0];

            // increment
            y+=gridSizeY;
            __syncthreads();
        }
        z+=gridSizeZ;
        __syncthreads();
    }
}

template <size_t BlockSize_numBeams>
__device__  void warpReduce_cx(volatile cuFloatComplex* sdata, int idx){
    // When 32 or fewer threads remain, there is only a single warp remaining and no need to synchronize; however,
    // the volatile keyword is necessary otherwise the compiler will optimize these operations into registers
    // and the result will be incorrect
    if (BlockSize_numBeams >= 64){
        sdata[idx].x += sdata[idx + 32].x;
        sdata[idx].y += sdata[idx + 32].y;
    }
    if (BlockSize_numBeams >= 32){
        sdata[idx].x += sdata[idx + 16].x;
        sdata[idx].y += sdata[idx + 16].y;
    }
    if (BlockSize_numBeams >= 16){
        sdata[idx].x += sdata[idx + 8].x;
        sdata[idx].y += sdata[idx + 8].y;
    }
    if (BlockSize_numBeams >= 8){
        sdata[idx].x += sdata[idx + 4].x;
        sdata[idx].y += sdata[idx + 4].y;
    }
    if (BlockSize_numBeams >= 4){
        sdata[idx].x += sdata[idx + 2].x;
        sdata[idx].y += sdata[idx + 2].y;
    }
    if (BlockSize_numBeams >= 2){
        sdata[idx].x += sdata[idx + 1].x;
        sdata[idx].y += sdata[idx + 1].y;
    }
}
~~~

The [presentation](http://developer.download.nvidia.com/compute/cuda/1.1-Beta/x86_website/projects/reduction/doc/reduction.pdf) I referenced on parallel reduction is extremely good, and if you have read through it then almost every step within `scaleReduceS` will be very clear. At the very beginning, we populate `coeff_cache`, which we read from global memory once and then will be reused at every position in `psi_ds` that we populate. The power of all of the statements like `if (BlockSizeX >= XX)` is that because `BlockSizeX` is a template parameter, it is visible at compile time, and thus these kinds of conditional checks don't have to be performed when you run PRISM simulations. They are effectively hard-coded into the functions, and when you are considering the parallel calculation consists of many thousands of threads each performing a relatively small number of operations, being able to skip *anything* can make quite a substantial difference in performance. I once again refer you to the talk if you want to get a sense of how much difference is made by the various optimizations used.

To finish, we just take one last fft and call the formatting function, which deals with transferring the result back to the host.

~~~ c++ 
//...
//...

// final fft
cufftErrchk(PRISM_CUFFT_EXECUTE(cufft_plan, &psi_ds[0], &psi_ds[0], CUFFT_FORWARD));

// convert to squared intensity
abs_squared <<< (psi_size - 1) / BLOCK_SIZE1D + 1, BLOCK_SIZE1D, 0, stream >>> (psi_intensity_ds, psi_ds, psi_size);

// output calculation result
formatOutput_GPU_integrate(pars, psi_intensity_ds, alphaInd_d, output_ph,
                           integratedOutput_ds, ay, ax, pars.imageSizeReduce[0],
                           pars.imageSizeReduce[1], stream, pars.scale);

~~~

You made it through! There are multiple variations of each of these functions, but if you understand what is happening in the streaming codes with batch FFTs then all of the other versions should also make sense.

<a name="gui"></a>
## Prismatic GUI  

The graphical user interface, `prismatic-gui`, is programmed with [Qt5](https://www.qt.io/), which is a cross-platform framework for programming GUIs. Qt is extremely rich, but it is also rather complicated and has a fairly steep learning curve if you want to understand how everything works together. I think the most important concept in Qt is the system of [signals and slots](http://doc.qt.io/qt-5/signalsandslots.html). Once you understand how signals and slots work with an event loop, GUI programming is simplified greatly, at least conceptually.  

GUI programming is pretty verbose, and so I'm not going to dump a bunch of code into this document, but I will make a few comments about the general process for building an application like `prismatic-gui`. All of the GUI code is contained with `Qt/` within the `Prismatic` package.

* The layout of the GUI was entirely done with Qt Designer. Some will argue that it is better to manually program the widgets, but I found Qt Designer to be totally sufficient for my purposes. I made extensive use of horizontal/vertical layouts to make things align and resize properly.
* Like the CLI, the GUI is used to create a `Metadata` object that is used to run the simulation. Custom slots were used to connect GUI widgets with the appropriate `Metadata` parameters. There is some parameter validation. So when a user changes a parameter, a signal is emitted that is connected to a slot that performs a parameter validation and, if this passes, then sets the appropriate `Metadata` parameter. 
* The "Full Calculation" button makes a copy of the current `Metadata` and runs the simulation. It's important to make a copy, otherwise the user could potentially continue to change the parameters while the simulation is running (bad). In addition, there is a lock that allows only one calculation to occur at a time. You may queue up multiple calculations, and a snapshot of the current settings for each will be saved and run correctly, but each simulation will run sequentially. The main reason for this is that `Prismatic` does some checks on GPU resources that are used to make decisions about how to proceed with the calculation, and if a second calculation begins there can be unexpected consequences. There shouldn't be any performance benefit to running multiple calculations in parallel, anyway. If your machine has more resources available, then you should just maximize their usage in each calculation.
* The images in the GUI are [QLabels](http://doc.qt.io/qt-5/qlabel.html) with a [QPixmap](http://doc.qt.io/qt-5/qpixmap.html). The GUI contains several `Prismatic::ArrayND` that hold data used to generate the images based upon the GUI settings. For example, once the sliced potential array is calculated, a copy of it is passed to the GUI. Any time one of the sliders for the potential image is moved, a signal-slot interaction is triggered that regenerates a `QImage` from this `Prismatic::ArrayND`, which involves a conversion from floating-point to 3-color `uchar`. This `QImage` is then used to generate a `QPixmap` which is displayed by the `QLabel`.

<a name="combining"></a>
## Combining CUDA and Qt with CMake

From the beginning of this project, the intention was to create an cross-platform program that could utilize GPUs, but still would work without them, and that had both a GUI and a CLI. My focus was very strongly on trying to make it as easy as possible to get it up and running no matter the user's hardware, OS, background, etc. After all, this is a tool, and if nobody wants to use it then what good have I accomplished?

That's a nice philosophy, but a lot easier said than done. The main challenge here is that NVIDIA has its own compiler, `nvcc` for compiling CUDA code, Qt has its own compiler, `moc`, which is an intermediate compiler that takes Qt specific directives for graphical objects and generates more C++ code which is then compiled with a normal C++ compiler like `gcc`. Getting source code to compile can be challenging on its own, so getting three different compilers to play nicely together alongsisde modern C++11 features and have it all run on Linux, Windows, and Mac was a bit daunting.

`CMake` was absolutely critical to making this possible. Not only can it handle the process of managing the different compilers and combining all of the intermediate results, but it also made it easy for me to create additional configuration options. For example, if you are just compiling *Prismatic* for the CLI, `prismatic`, to run on a cluster -- you probably don't care about about building the GUI, which requires several libraries from the rather large Qt framework. By setting the CMake option `PRISM_ENABLE_GPU=0`, simple logic prevents compilation from ever including anything about Qt. The same goes for enabling GPU support. So by default, *Prismatic* compiles under the simplest of settings, only building the CLI with command line support without GPUs, and then the user can expand from there based upon their needs.

### Conclusion

*I hope you found this walkthrough interesting. If you have comments, corrections, advice, criticisms, questions, or just want to talk about this (or really any other computing topic..), feel free to reach out to me via email (apryor6@gmail.com)*

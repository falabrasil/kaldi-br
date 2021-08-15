# Kaldi installation instructions

## Install GCC 8 suite (Arch Linux only)

:warning: Since I am running Arch Linux, which defaults to GCC 11.1.0 as of
June 2021, I had therefore to use version 8 of the C compiler suite, which is
the one which both C++11 standard and CUDA/NVIDIA drivers do not complain.
Debian-based distro might skip this part, as well as omit further `CC`,
`CXX`, and other Makefile implicit variables.

```text
$ yay -S gcc8-libs gcc8-fortran gcc8
```

```bash
$ gcc-8 --version       # returns `gcc-8 (GCC) 8.4.0`
$ g++-8 --version       # returns `g++-8 (GCC) 8.4.0`
$ gfortran-8 --version  # returns `GNU Fortran (GCC) 8.4.0`
```


## Install NVIDIA drivers and CUDA

Of course this is required if and only if you have a GPU card (and you should,
otherwise you'd better look for other options such as Google Colab). These
instructions apply for Arch Linux users. Debian users should use `apt`- or
`dpkg`-like utilities.

```text
# pacman -S nvidia cuda cudnn
```

To check whether CUDA installation was successful, you can run some examples,
the most common being query the GPU card device.
This, however, requires that `/opt/cuda/bin/` dir is included in the `$PATH`
env var, since it needs to be able to find NVCC compiler there. Debian-based
users should look into `/usr/local/share/cuda/` or `/usr/local/cuda/` dirs.

```bash
$ cd /opt/cuda/samples/1_Utilities/deviceQuery
$ sudo PATH=$PATH:/opt/cuda/bin make
$ ./deviceQuery
```

Finally, the device query output should look something like the following. My
card is a GeForce MX150 running on CUDA v11.

```text
./deviceQuery Starting...

 CUDA Device Query (Runtime API) version (CUDART static linking)

Detected 1 CUDA Capable device(s)

Device 0: "GeForce MX150"
  CUDA Driver Version / Runtime Version          11.1 / 11.0
  CUDA Capability Major/Minor version number:    6.1
  Total amount of global memory:                 2003 MBytes (2099904512 bytes)
  ( 3) Multiprocessors, (128) CUDA Cores/MP:     384 CUDA Cores
  GPU Max Clock rate:                            1532 MHz (1.53 GHz)
  Memory Clock rate:                             3004 Mhz
  Memory Bus Width:                              64-bit
  L2 Cache Size:                                 524288 bytes
  Maximum Texture Dimension Size (x,y,z)         1D=(131072), 2D=(131072, 65536), 3D=(16384, 16384, 16384)
  Maximum Layered 1D Texture Size, (num) layers  1D=(32768), 2048 layers
  Maximum Layered 2D Texture Size, (num) layers  2D=(32768, 32768), 2048 layers
  Total amount of constant memory:               65536 bytes
  Total amount of shared memory per block:       49152 bytes
  Total number of registers available per block: 65536
  Warp size:                                     32
  Maximum number of threads per multiprocessor:  2048
  Maximum number of threads per block:           1024
  Max dimension size of a thread block (x,y,z): (1024, 1024, 64)
  Max dimension size of a grid size    (x,y,z): (2147483647, 65535, 65535)
  Maximum memory pitch:                          2147483647 bytes
  Texture alignment:                             512 bytes
  Concurrent copy and kernel execution:          Yes with 2 copy engine(s)
  Run time limit on kernels:                     No
  Integrated GPU sharing Host Memory:            No
  Support host page-locked memory mapping:       Yes
  Alignment requirement for Surfaces:            Yes
  Device has ECC support:                        Disabled
  Device supports Unified Addressing (UVA):      Yes
  Device supports Managed Memory:                Yes
  Device supports Compute Preemption:            Yes
  Supports Cooperative Kernel Launch:            Yes
  Supports MultiDevice Co-op Kernel Launch:      Yes
  Device PCI Domain ID / Bus ID / location ID:   0 / 2 / 0
  Compute Mode:
     < Default (multiple host threads can use ::cudaSetDevice() with device simultaneously) >

deviceQuery, CUDA Driver = CUDART, CUDA Driver Version = 11.1, CUDA Runtime Version = 11.0, NumDevs = 1
Result = PASS
```

Type `nvidia-smi` on your terminal to check the status as well.


## Download and install Kaldi

First, clone Kaldi from GitHub:

```bash
$ git clone https://github.com/kaldi-asr/kaldi
```

Then install Kaldi `tools` plus OpenBLAS lib (we don't like Intel MKL very much):

```bash
$ cd kaldi/tools
$ CC=gcc-8 CXX=g++-8 FC=gfortran-8 extras/check_dependencies.sh
$ CC=gcc-8 CXX=g++-8 FC=gfortran-8 make -j 6
$ CC=gcc-8 CXX=g++-8 FC=gfortran-8 extras/install_openblas.sh
```

Finally, install Kaldi `src`.
If you do not have an NVIDIA driver, then CUDA dir is optional. On the other
hand, if you do have a GPU and your distro is Debian-based (e.g., Ubuntu), the
`cudatk-dir` parameter is also optional because it's automatically inferred by
the `configure` script.

```bash
$ cd kaldi/src
$ CC=gcc-8 CXX=g++-8 FC=gfortran-8 ./configure --shared --cudatk-dir=/opt/cuda/ --mathlib=OPENBLAS
$ CC=gcc-8 CXX=g++-8 FC=gfortran-8 make depend -j 6
$ CC=gcc-8 CXX=g++-8 FC=gfortran-8 make -j 6
```

To guarantee Kaldi installation was successful, run the scripts on the `yes/no`
dataset. It doesn't take long to finish since the dataset is pretty small and
the pipeline only trains and decodes a monophone-based model. This does not
guarantee that the GPU is working, though.

```bash
$ cd kaldi/egs/yesno/s5
$ bash run.sh
```

The last line should print the word error rate:

```text
%WER 0.00 [ 0 / 232, 0 ins, 0 del, 0 sub ] exp/mono0a/decode_test_yesno/wer_10_0.0
```


[![FalaBrasil](doc/logo_fb_github_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](doc/logo_ufpa_github_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2021)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    

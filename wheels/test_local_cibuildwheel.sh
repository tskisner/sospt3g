#!/bin/bash

# Before running this from the so3g git checkout directory,
# you should pip install cibuildwheel

export CIBW_DEBUG_KEEP_CONTAINER=TRUE

export CIBW_BUILD="cp312-manylinux_x86_64"
export CIBW_MANYLINUX_X86_64_IMAGE="manylinux2014"
export CIBW_BUILD_VERBOSITY=3
export CIBW_ENVIRONMENT_LINUX="CC=gcc CXX=g++ CFLAGS='-O3 -fPIC' CXXFLAGS='-O3 -fPIC -std=c++17' CMAKE_ARGS='-DCMAKE_VERBOSE_MAKEFILE=ON'"
export CIBW_BEFORE_BUILD_LINUX="./wheels/install_deps_linux.sh; python -c 'import numpy; print(numpy.get_include())'"
export CIBW_REPAIR_WHEEL_COMMAND_LINUX="./wheels/repair_wheel_linux.sh {dest_dir} {wheel}"
export CIBW_BEFORE_TEST="export OMP_NUM_THREADS=2"
export CIBW_TEST_REQUIRES=
export CIBW_TEST_COMMAND="ldd $(dirname $(python -c 'import spt3g; print(spt3g.__file__)'))/_libcore*.so; python -c 'import spt3g'; python -c 'import spt3g; from spt3g import _libcore'; python -c 'from spt3g import core; from spt3g import so'"

# Get the current date for logging
now=$(date "+%Y-%m-%d_%H:%M:%S")

# Run it
cibuildwheel --platform linux --archs x86_64 --output-dir wheelhouse . 2>&1 | tee log_${now}


#!/bin/bash
#
# This script is designed to run within a container managed by cibuildwheel.
# This will use a recent version of OS X.
#

set -e

# Location of this script
pushd $(dirname $0) >/dev/null 2>&1
scriptdir=$(pwd)
popd >/dev/null 2>&1
echo "Wheel script directory = ${scriptdir}"

# Build in a subdirectory
depbuild="${scriptdir}/../deps"
mkdir -p "${depbuild}"
pushd "${depbuild}"

# Build options.

#use_gcc=yes
use_gcc=no
gcc_version=14

if [ "x${use_gcc}" = "xyes" ]; then
    CC=gcc-${gcc_version}
    CXX=g++-${gcc_version}
    CFLAGS="-O3 -fPIC"
    CXXFLAGS="-O3 -fPIC -std=c++17"
    OMPFLAGS="-fopenmp"
else
    export MACOSX_DEPLOYMENT_TARGET=$(python3 -c "import sysconfig as s; print(s.get_config_vars()['MACOSX_DEPLOYMENT_TARGET'])")
    echo "Using MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}"
    CC=clang
    CXX=clang++
    CFLAGS="-O3 -fPIC"
    CXXFLAGS="-O3 -fPIC -std=c++17 -stdlib=libc++"
    OMPFLAGS=""
fi

MAKEJ=2

PREFIX=/usr/local

# Workaround permissions on macos-14 github runner
# https://github.com/actions/runner-images/issues/9272
sudo chown -R runner:admin /usr/local

# Optionally install gcc
if [ "x${use_gcc}" = "xyes" ]; then
    brew install gcc@${gcc_version}
fi

# Update pip
pip install --upgrade pip

# Install a couple of base packages that are always required
pip install -v cmake wheel setuptools

# In order to maximize ABI compatibility with numpy, build with the newest numpy
# version containing the oldest ABI version compatible with the python we are using.
# NOTE: for now, we build with numpy 2.0.x, which is backwards compatible with
# numpy-1.x and forward compatible with numpy-2.x.
pyver=$(python3 --version 2>&1 | awk '{print $2}' | sed -e "s#\(.*\)\.\(.*\)\..*#\1.\2#")
# # if [ ${pyver} == "3.8" ]; then
# #     numpy_ver="1.20"
# # fi
# # if [ ${pyver} == "3.9" ]; then
# #     numpy_ver="1.20"
# # fi
# # if [ ${pyver} == "3.10" ]; then
# #     numpy_ver="1.22"
# # fi
# # if [ ${pyver} == "3.11" ]; then
# #     numpy_ver="1.24"
# # fi
# numpy_ver="2.0.1"

# Install build requirements.
CC="${CC}" CFLAGS="${CFLAGS}" pip install -v "numpy" scipy astropy

# Install boost

boost_version=1_87_0
boost_dir=boost_${boost_version}
boost_pkg=${boost_dir}.tar.bz2

echo "Fetching boost..."

if [ ! -e ${boost_pkg} ]; then
    curl -SL "https://archives.boost.io/release/1.87.0/source/${boost_pkg}" -o "${boost_pkg}"
fi

echo "Building boost..."

pyincl=$(for d in $(python3-config --includes | sed -e 's/-I//g'); do echo "include=${d}"; done | xargs)

use_line="using darwin : : ${CXX} ;"
extra_link="linkflags=\"-stdlib=libc++\""
if [ "x${use_gcc}" = "xyes" ]; then
    use_line="using gcc : : ${CXX} ;"
    extra_link=""
fi

rm -rf ${boost_dir}
tar xjf ${boost_pkg} \
    && pushd ${boost_dir} \
    && echo ${use_line} > tools/build/user-config.jam \
    && echo "option jobs : ${MAKEJ} ;" >> tools/build/user-config.jam \
    && BOOST_BUILD_USER_CONFIG=tools/build/user-config.jam \
    ./bootstrap.sh \
    --with-python=python3 \
    --prefix=${PREFIX} \
    && ./b2 --layout=tagged --user-config=./tools/build/user-config.jam \
    ${pyincl} -sNO_LZMA=1 -sNO_ZSTD=1 \
    cxxflags="${CXXFLAGS}" ${extra_link} \
    variant=release threading=multi link=shared runtime-link=shared install \
    && popd >/dev/null 2>&1

# Install libFLAC

flac_version=1.4.3
flac_dir=flac-${flac_version}
flac_pkg=${flac_dir}.tar.gz

echo "Fetching libFLAC..."

if [ ! -e ${flac_pkg} ]; then
    curl -SL "https://github.com/xiph/flac/archive/refs/tags/${flac_version}.tar.gz" -o "${flac_pkg}"
fi

echo "Building libFLAC..."

rm -rf ${flac_dir}
tar xzf ${flac_pkg} \
    && pushd ${flac_dir} >/dev/null 2>&1 \
    && mkdir -p build \
    && pushd build >/dev/null 2>&1 \
    && cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DBUILD_DOCS=OFF \
    -DWITH_OGG=OFF \
    -DBUILD_CXXLIBS=OFF \
    -DBUILD_PROGRAMS=OFF \
    -DBUILD_UTILS=OFF \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DINSTALL_MANPAGES=OFF \
    -DENABLE_MULTITHREADING=ON \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    .. \
    && make -j ${MAKEJ} install \
    && popd >/dev/null 2>&1 \
    && popd >/dev/null 2>&1

popd

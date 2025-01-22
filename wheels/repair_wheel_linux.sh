#!/bin/bash
#
# This script runs the "usual" command to repair wheels, but adds the
# build directory to the library search path so that the spt3g / so3g
# libraries can be found
#

set -e

dest_dir=$1
wheel=$2

export LD_LIBRARY_PATH="/usr/local/lib":"/usr/local/lib64":${LD_LIBRARY_PATH}

auditwheel repair -w ${dest_dir} ${wheel}

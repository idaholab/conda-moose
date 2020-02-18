#!/bin/bash

export CC=$(basename "$CC")
export CXX=$(basename "$CXX")
export FC=$(basename "$FC")
unset CPPFLAGS CFLAGS CXXFLAGS FFLAGS FCFLAGS F90 F77
if [[ $(uname) == Darwin ]]; then
    SHARED=clang
else
    SHARED=gcc
fi
TUNING="-march=core2 -mtune=haswell"
./configure --prefix=$PREFIX \
            --enable-shared \
            --enable-sharedlibs=$SHARED \
            --enable-fast=O2 \
            --enable-debuginfo \
            --enable-two-level-namespace \
            CC=$CC CXX=$CXX FC=$FC F77=$FC F90='' \
            CFLAGS="$TUNNING" CXXFLAGS="$TUNNING" FFLAGS="$TUNNING" LDFLAGS="${LDFLAGS:-}" \
            FCFLAGS="$TUNNING" F90FLAGS='' F77FLAGS=''

make -j"${CPU_COUNT:-1}"
make install

# Set PETSC_DIR environment variable for those that need it
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat <<EOF > "${PREFIX}/etc/conda/activate.d/activate_${PKG_NAME}.sh"
export MPIHOME=${PREFIX}
EOF
cat <<EOF > "${PREFIX}/etc/conda/deactivate.d/deactivate_${PKG_NAME}.sh"
unset MPIHOME
EOF

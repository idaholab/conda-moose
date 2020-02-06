#!/bin/bash

export CC=$(basename "$CC")
export CXX=$(basename "$CXX")
export FC=$(basename "$FC")
unset CPPFLAGS CFLAGS CXXFLAGS FFLAGS FCFLAGS LDFLAGS F90 F77
if [[ $(uname) == Darwin ]]; then
    SHARED=clang
    export LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
    export LIBRARY_PATH="$PREFIX/lib"
else
    SHARED=gcc
fi
./configure --prefix=$PREFIX \
            --enable-shared \
            --enable-sharedlibs=$SHARED \
            --enable-fast=O2 \
            --enable-debuginfo \
            --enable-two-level-namespace \
            CC=$CC CXX=$CXX FC=$FC F77=$FC F90='' \
            CFLAGS='' CXXFLAGS='' FFLAGS='' LDFLAGS="${LDFLAGS:-}" \
            FCFLAGS='' F90FLAGS='' F77FLAGS=''

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

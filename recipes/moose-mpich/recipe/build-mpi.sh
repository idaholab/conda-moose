#!/bin/bash

# configure balks if F90 is defined
# with a fatal deprecation message pointing to FC
unset F90 F77

export FCFLAGS="$FFLAGS"

# avoid absolute-paths in compilers
export CC=$(basename "$CC")
export CXX=$(basename "$CXX")
export FC=$(basename "$FC")

# avoid recording flags in compilers
# See Compiler Flags section of MPICH readme
# TODO: configure ignores MPICHLIB_LDFLAGS
export MPICHLIB_CPPFLAGS=$CPPFLAGS
unset CPPFLAGS
export MPICHLIB_CFLAGS=$CFLAGS
unset CFLAGS
export MPICHLIB_CXXFLAGS=$CXXFLAGS
unset CXXFLAGS
export MPICHLIB_LDFLAGS=$LDFLAGS
unset LDFLAGS
export MPICHLIB_FFLAGS=$FFLAGS
unset FFLAGS
export MPICHLIB_FCFLAGS=$FCFLAGS
unset FCFLAGS

# set some specific flags that we *do* want recorded in the compilers
# only the bare minimum of prefix-awareness here
export CPPFLAGS="-I$PREFIX/include"
export CFLAGS="-I$PREFIX/include"
export CXXFLAGS="-I$PREFIX/include"
export FFLAGS="-I$PREFIX/include"
export FCFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"

export LIBRARY_PATH="$PREFIX/lib"

./configure --prefix=$PREFIX \
            --disable-dependency-tracking \
            --enable-cxx \
            --enable-fortran \
            --disable-wrapper-rpath \
            --enable-two-level-namespace

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

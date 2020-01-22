#!/bin/bash
set -eu
export PETSC_DIR=$SRC_DIR
export PETSC_ARCH=arch-conda-c-opt

unset F90
unset F77
unset CC
unset CXX
if [[ $(uname) == Linux ]]; then
    export LDFLAGS="-pthread -fopenmp $LDFLAGS"
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
    # --as-needed appears to cause problems with fortran compiler detection
    # due to missing libquadmath
    # unclear why required libs are stripped but still linked
    export FFLAGS="${FFLAGS:-} -Wl,--no-as-needed"
else
    export LDFLAGS="${LDFLAGS:-} -Wl,-headerpad_max_install_names"
fi

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export FFLAGS=$(echo ${FFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')

if [[ $mpi == "openmpi" ]]; then
  export LIBS="-Wl,-rpath,$PREFIX/lib -lmpi_mpifh -lgfortran"
elif [[ $mpi == "moose-mpich" ]]; then
  export LIBS="-lmpifort -lgfortran"
fi

if [[ $mpi == "openmpi" ]]; then
  export OMPI_MCA_plm=isolated
  export OMPI_MCA_rmaps_base_oversubscribe=yes
  export OMPI_MCA_btl_vader_single_copy_mechanism=none
elif [[ $mpi == "moose-mpich" ]]; then
  export HYDRA_LAUNCHER=fork
fi
export PETSC_PREFIX=${PREFIX}/petsc
python ./configure \
  AR="${AR:-ar}" \
  CC="mpicc" \
  CXX="mpicxx" \
  FC="mpifort" \
  CFLAGS="$CFLAGS" \
  CPPFLAGS="$CPPFLAGS" \
  CXXFLAGS="$CXXFLAGS" \
  FFLAGS="$FFLAGS" \
  LDFLAGS="$LDFLAGS" \
  LIBS="${LIBS:-}" \
  --COPTFLAGS=-O3 \
  --CXXOPTFLAGS=-O3 \
  --FOPTFLAGS=-O3 \
  --with-clib-autodetect=0 \
  --with-cxxlib-autodetect=0 \
  --with-fortranlib-autodetect=0 \
  --with-debugging=0 \
  --with-blas-lib=libblas${SHLIB_EXT} \
  --with-lapack-lib=liblapack${SHLIB_EXT} \
  --with-hwloc=0 \
  --with-mpi=1 \
  --with-pthread=1 \
  --with-shared-libraries \
  --with-scalapack=1 \
  --with-mumps=1 \
  --with-ssl=0 \
  --with-x=0 \
  --download-hypre=1 \
  --download-metis=1 \
  --download-superlu=1 \
  --download-parmetis=1 \
  --download-ptscotch=1 \
  --download-suitesparse=1 \
  --with-cxx-dialect=C++11 \
  --download-superlu_dist=1 \
  --prefix=$PETSC_PREFIX || (cat configure.log && exit 1)

# Verify that gcc_ext isn't linked
for f in $PETSC_ARCH/lib/petsc/conf/petscvariables $PETSC_ARCH/lib/pkgconfig/PETSc.pc; do
  if grep gcc_ext $f; then
    echo "gcc_ext found in $f"
    exit 1
  fi
done

sedinplace() {
  if [[ $(uname) == Darwin ]]; then
    sed -i "" "$@"
  else
    sed -i"" "$@"
  fi
}

# Remove abspath of ${BUILD_PREFIX}/bin/python
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/include/petscconf.h
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/lib/petsc/conf/petscvariables
sedinplace "s%${BUILD_PREFIX}/bin/python%/usr/bin/env python%g" $PETSC_ARCH/lib/petsc/conf/reconfigure-arch-conda-c-opt.py

# Replace abspath of ${PETSC_DIR} and ${BUILD_PREFIX} with ${PREFIX}
for path in $PETSC_DIR $BUILD_PREFIX; do
    for f in $(grep -l "${path}" $PETSC_ARCH/include/petsc*.h); do
        echo "Fixing ${path} in $f"
        sedinplace s%$path%\${PETSC_PREFIX}%g $f
    done
done

make

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make check MPIEXEC="${RECIPE_DIR}/mpiexec.sh"

make install

# Remove unneeded files
rm -f ${PETSC_PREFIX}/lib/petsc/conf/configure-hash
find ${PETSC_PREFIX}/lib/petsc -name '*.pyc' -delete

# Replace ${BUILD_PREFIX} after installation,
# otherwise 'make install' above may fail
for f in $(grep -l "${BUILD_PREFIX}" -R "${PETSC_PREFIX}/lib/petsc"); do
  echo "Fixing ${BUILD_PREFIX} in $f"
  sedinplace s%${BUILD_PREFIX}%${PETSC_PREFIX}%g $f
done

echo "Removing example files"
du -hs $PETSC_PREFIX/share/petsc/examples/src
rm -fr $PETSC_PREFIX/share/petsc/examples/src
echo "Removing data files"
du -hs $PETSC_PREFIX/share/petsc/datafiles/*
rm -fr $PETSC_PREFIX/share/petsc/datafiles

# Set PETSC_DIR environment variable for those that need it
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat <<EOF > "${PREFIX}/etc/conda/activate.d/activate_${PKG_NAME}.sh"
export PETSC_DIR=${PETSC_PREFIX}
export PKG_CONFIG_PATH=${PETSC_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
EOF
cat <<EOF > "${PREFIX}/etc/conda/deactivate.d/deactivate_${PKG_NAME}.sh"
unset PETSC_DIR
EOF

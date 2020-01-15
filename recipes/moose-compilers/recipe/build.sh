#!/bin/bash
set -eu
install -d $PREFIX/share
install -m 644 moose-compilers $PREFIX/share
# Allow mpirun/exec to oversubscribe without errors
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat <<EOF > "${PREFIX}/etc/conda/activate.d/activate_${PKG_NAME}.sh"
export MOOSE_NO_CODESIGN=true
if type which ccache > /dev/null 2>&1; then
  extra_options="ccache "
  export CCACHE_SLOPPINESS="time_macros"
fi
export CC=\${extra_options:-}mpicc CXX=\${extra_options:-}mpicxx FC=mpif90 F90=mpif90 F77=mpif77
EOF
cat <<EOF > "${PREFIX}/etc/conda/deactivate.d/deactivate_${PKG_NAME}.sh"
unset MOOSE_NO_CODESIGN CCACHE_SLOPPINESS CC CXX FC F90 F77
EOF

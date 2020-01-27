#!/bin/bash
set -eu
if [[ $mpi == "openmpi" ]]; then
  export OMPI_MCA_plm=isolated
  export OMPI_MCA_rmaps_base_oversubscribe=yes
  export OMPI_MCA_btl_vader_single_copy_mechanism=none
elif [[ $mpi == "moose-mpich" ]]; then
  export HYDRA_LAUNCHER=fork
fi
export CC=mpicc CXX=mpicxx
mkdir -p build
cd build
VTK_PREFIX=${PREFIX}/libmesh-vtk
cmake .. -G "Ninja" \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH:PATH=${VTK_PREFIX} \
    -DCMAKE_INSTALL_PREFIX:PATH=${VTK_PREFIX} \
    -DCMAKE_INSTALL_RPATH:PATH=${VTK_PREFIX}/lib \
    -DCMAKE_INSTALL_LIBDIR:PATH=lib \
    -DBUILD_DOCUMENTATION:BOOL=OFF \
    -DBUILD_TESTING:BOOL=OFF \
    -DBUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DVTK_Group_MPI:BOOL=ON \
    -DVTK_Group_Rendering:BOOL=OFF \
    -DVTK_Group_Qt:BOOL=OFF \
    -DVTK_Group_Views:BOOL=OFF \
    -DVTK_Group_Web:BOOL=OFF

ninja install -v

# Set LIBMESH_DIR environment variable for those that need it
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat <<EOF > "${PREFIX}/etc/conda/activate.d/activate_${PKG_NAME}.sh"
export VTKLIB_DIR=${VTK_PREFIX}/lib
export VTKINCLUDE_DIR=${VTK_PREFIX}/include/vtk-${friendly_version}
EOF
cat <<EOF > "${PREFIX}/etc/conda/deactivate.d/deactivate_${PKG_NAME}.sh"
unset VTKLIB_DIR
unset VTKINCLUDE_DIR
EOF

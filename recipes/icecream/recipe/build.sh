#!/bin/bash
set -eu
export PKG_CONFIG_PATH=$PREFIX/icecream-deps/lib/pkgconfig:$PKG_CONFIG_PATH
unset F90
unset F77
unset CC
unset CXX

# LZO
cd lzo
if [ `uname` = "Linux" ]; then
    export CXXFLAGS="-std=c++11" CFLAGS="-std=c++11"
fi
./configure --prefix="$PREFIX/icecream-deps"
make -j $CPU_COUNT
make install
if [ `uname` = "Linux" ]; then
    unset CXXFLAGS CFLAGS
fi
cd ../

# libcap is only a necessary dependency on Linux machines
if [ `uname` = "Linux" ]; then
    cd libcap
    ./configure --prefix="$PREFIX/icecream-deps"
    make -j $CPU_COUNT
    make install
    cd ../
fi

# ZSTD
cd zstd
make prefix="$PREFIX/icecream-deps"
make prefix="$PREFIX/icecream-deps" install
cd ../

# LIBARCHIVE
cd libarchive
./configure --prefix="$PREFIX/icecream-deps"
make -j $CPU_COUNT
make install
cd ../

cd icecream
./autogen.sh
if [ `uname` = "Darwin" ]; then
    LDFLAGS="-L$PREFIX/icecream-deps/lib -llzo2 `pkg-config libzstd libarchive --libs`" CPPFLAGS="-I$PREFIX/icecream-deps/include `pkg-config libzstd libarchive --cflags`" CFLAGS="`pkg-config libzstd libarchive --cflags`" ./configure --prefix="$PREFIX/icecream" --without-man
else
    LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}
    LD_LIBRARY_PATH="`pkg-config libzstd --variable=prefix`/lib:`pkg-config libarchive --variable=prefix`/lib:$LD_LIBRARY_PATH" LDFLAGS="-L$PREFIX/icecream-deps/lib -llzo2 -L$PREFIX/icecream-deps/lib -lcap-ng `pkg-config libzstd libarchive --libs`" CPPFLAGS="-I$PREFIX/icecream-deps/include -I$PREFIX/icecream-deps/include `pkg-config libzstd libarchive --cflags`" CFLAGS="`pkg-config libzstd libarchive --cflags`" ./configure --prefix="$PREFIX/icecream" --without-man
fi
make -j $CPU_COUNT
make install

cd ${PREFIX}/icecream/libexec/icecc/bin
if [ `uname` = "Darwin" ]; then
    ln -s ../../../bin/icecc x86_64-apple-darwin13.4.0-clang
    ln -s ../../../bin/icecc x86_64-apple-darwin13.4.0-clang++
fi
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat <<EOF > "${PREFIX}/etc/conda/activate.d/activate_${PKG_NAME}.sh"
export PATH=${PREFIX}/icecream/bin:${PREFIX}/icecream/sbin:\$PATH
EOF

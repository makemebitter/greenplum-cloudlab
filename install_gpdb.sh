#!/bin/bash
set -e
# greenplum
export DEBIAN_FRONTEND=noninteractive

# gp-xerces
cd /local/gp-xerces
mkdir build
cd build
../configure --prefix=/usr/local
make
sudo make install

# gp-orca 
cd /local/gporca
cmake -GNinja -H. -Bbuild
sudo ninja install -C build

# gpdb
cd /local/gpdb_src
git checkout 5X_STABLE
./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb
make -j
make -j install
/usr/local/gpdb/bin/generate-greenplum-path.sh
source /usr/local/gpdb/greenplum_path.sh

# madlib
cd /local/madlib;
mkdir build;
cd build;
cmake ..;
make -j;


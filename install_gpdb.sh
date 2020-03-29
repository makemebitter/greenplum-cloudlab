#!/bin/bash
duty=${1}
set -e
eval `ssh-agent`
ssh-add /local/gpdb_key
awk 'NR>1 {print $NF}' /etc/hosts | grep -v 'master' > /local/gphost_list


# # greenplum
# export DEBIAN_FRONTEND=noninteractive

# # gp-xerces
# cd /local/gp-xerces
# mkdir build
# cd build
# ../configure --prefix=/usr/local/gpdb
# make
# sudo make install

# # gp-orca 
# cd /local/gporca
# cmake -DCMAKE_INSTALL_PREFIX=/usr/local -GNinja -H. -Bbuild 
# sudo ninja install -C build

# sudo ldconfig
# # gpdb

# cd /local/gpdb_src
# git checkout 5X_STABLE
# ./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb
# make -j
sudo make -j install


# GPDB ppa ------------––------------------------------------------------------
sudo add-apt-repository -y ppa:greenplum/db
sudo apt-get update
sudo apt-get install -y greenplum-db-oss
sudo chown -R gpadmin:gpadmin /opt/gpdb
source /opt/gpdb/greenplum_path.sh
# -------––--------------------------------------------------------------------



# if [ "$duty" = "m" ]; then
# 	/usr/local/gpdb/bin/generate-greenplum-path.sh
# 	source /usr/local/gpdb/greenplum_path.sh
# 	echo "source /usr/local/gpdb/greenplum_path.sh" >> ~/.bashrc
# 	pip install paramiko;
# 	gpssh-exkeys -f /local/gphost_list
# 	cp /local/repository/gpinitsystem_config /local/gpinitsystem_config
# 	gpinitsystem -a -c /local/gpinitsystem_config -h /local/gphost_list
# 	# madlib
# 	cd /local/madlib;
# 	mkdir build;
# 	cd build;
# 	cmake ..;
# 	make -j;
# fi
#!/bin/bash
duty=${1}
set -e
echo 'eval `ssh-agent` &> /dev/null' >> ~/.bashrc
echo "ssh-add /local/gpdb_key &> /dev/null" >> ~/.bashrc
source ~/.bashrc
awk 'NR>1 {print $NF}' /etc/hosts | grep -v 'master' > /local/gphost_list
echo "RemoveIPC=no" | sudo tee -a /etc/systemd/logind.conf
sudo service systemd-logind restart

# greenplum
export DEBIAN_FRONTEND=noninteractive

# gp-xerces
cd /local/gp-xerces
mkdir build
cd build
../configure --prefix=/usr/local/gpdb
make
sudo make install

# gp-orca 
cd /local/gporca
cmake -DCMAKE_INSTALL_PREFIX=/usr/local -GNinja -H. -Bbuild 
sudo ninja install -C build

sudo ldconfig
# gpdb

cd /local/gpdb_src
git checkout 5X_STABLE
./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb
make -j
sudo make -j install

# Important missing dependency
pip install paramiko;

# GPDB ppa ------------––------------------------------------------------------
# sudo add-apt-repository -y ppa:greenplum/db
# sudo apt-get update
# sudo apt-get install -y greenplum-db-oss
# sudo chown -R gpadmin:gpadmin /opt/gpdb
# source /opt/gpdb/greenplum_path.sh
# -------––--------------------------------------------------------------------


echo "GPDB INSTALLATION FINISHED"
if [ "$duty" = "m" ]; then
	/usr/local/gpdb/bin/generate-greenplum-path.sh
	echo "source /usr/local/gpdb/greenplum_path.sh" >> ~/.bashrc
	source ~/.bashrc
	gpssh-exkeys -f /local/gphost_list
	cp /local/repository/gpinitsystem_config /local/gpinitsystem_config
	gpinitsystem -a -c /local/gpinitsystem_config -h /local/gphost_list
	echo "GPDB INITIALIZATION FINISHED"
	# madlib
	cd /local/madlib;
	mkdir build;
	cd build;
	cmake ..;
	make -j;
fi
echo "GPDB SCRIPT EXISTING"

#!/bin/bash
duty=${1}
set -e
# system settings
echo 'eval `ssh-agent` &> /dev/null' >> ~/.bashrc
echo "ssh-add /local/gpdb_key &> /dev/null" >> ~/.bashrc
echo 'export PYTHONPATH="${PYTHONPATH}:/usr/local/lib/python2.7/dist-packages"' >> ~/.bashrc
echo 'export WORKER_NAME=$(cat /proc/sys/kernel/hostname | cut -d'.' -f1)' | sudo tee -a ~/.bashrc
echo 'export WORKER_NUMBER=$(sed -n -e 's/^.*worker//p' <<<"$WORKER_NAME")' | sudo tee -a ~/.bashrc
source ~/.bashrc
echo "RemoveIPC=no" | sudo tee -a /etc/systemd/logind.conf
sudo service systemd-logind restart
echo -e 'gpadmin hard core unlimited\ngpadmin hard nproc 131072\ngpadmin hard nofile 65536' | sudo tee -a /etc/security/limits.d/gpadmin-limits.conf




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

# refresh dynamic libs
sudo ldconfig

# gpdb
cd /local/gpdb_src
git checkout 5X_STABLE
./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb
make -j
sudo make -j install
/usr/local/gpdb/bin/generate-greenplum-path.sh
echo 'source /usr/local/gpdb/greenplum_path.sh' >> ~/.bashrc
source ~/.bashrc
sudo chown -R gpadmin:gpadmin /usr/local/gpdb
# important missing dependency
sudo pip install paramiko;

# madlib
cd /local/madlib;
mkdir build;
cd build;
cmake ..;
make -j;





# GPDB ppa use if above doen't work -––----------------------------------------
# sudo add-apt-repository -y ppa:greenplum/db
# sudo apt-get update
# sudo apt-get install -y greenplum-db-oss
# sudo chown -R gpadmin:gpadmin /opt/gpdb
# source /opt/gpdb/greenplum_path.sh
# -------––--------------------------------------------------------------------



echo "GPDB INSTALLATION FINISHED"
if [ "$duty" = "m" ]; then
    FILE_PATH=/local/gphost_list
    TAG_PATH=/local/SUCCESS
    readarray -t hosts < $FILE_PATH
    while true; do
        echo "Checking if all hosts finished"
        all_done=true
        for host in "${hosts[@]}"; do
            if ssh -o StrictHostKeychecking=no $host stat $TAG_PATH \> /dev/null 2\>\&1; then
                echo "$host finished"
            else
                echo "$host hasn't finished yet"
                all_done=false
            fi
        done
        

        if [ "$all_done" = true ] ; then
            echo "GPDB INITIALIZATION STARTING"
            sudo hostnamectl set-hostname master
            gpssh-exkeys -f /local/gphost_list
            gpssh-exkeys -h master
            cp /local/repository/gpinitsystem_config /local/gpinitsystem_config
            set +e
            gpinitsystem -a -c /local/gpinitsystem_config -h /local/gphost_list
            echo $?
            set -e
            echo 'export MASTER_DATA_DIRECTORY=/mnt/gpdata_master/gpseg-1' >> /usr/local/gpdb/greenplum_path.sh
            /local/madlib/build/src/bin/madpack -p greenplum -c gpadmin@master:5432/cerebro install
            break
        else
            echo "WAITING"
            sleep 5s
        fi
    done
    echo "GPDB INITIALIZATION FINISHED"    
fi
echo "GPDB SCRIPT EXISTING"

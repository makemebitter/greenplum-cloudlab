#!/bin/bash
duty=${1}
set -e
FILE_PATH=/local/gphost_list
TAG_PATH=/local/GPDB_SUCCESS
# system settings
echo 'eval `ssh-agent` &> /dev/null' >> ~/.bashrc
echo "ssh-add /local/gpdb_key &> /dev/null" >> ~/.bashrc
echo 'export PYTHONPATH="${PYTHONPATH}:/usr/local/lib/python2.7/dist-packages"' >> ~/.bashrc
echo 'export WORKER_NAME=$(cat /proc/sys/kernel/hostname | cut -d'.' -f1)' | sudo tee -a ~/.bashrc
echo 'export WORKER_NUMBER=$(sed -n -e 's/^.*worker//p' <<<"$WORKER_NAME")' | sudo tee -a ~/.bashrc
echo '[[ -s ~/.bashrc ]] && source ~/.bashrc' >> ~/.bash_profile

sudo bash -c 'cat >> /home/gpadmin/.bashrc <<-EOF
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, dont overwrite it

# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF'

cat /users/yhzhang/.bashrc | sudo tee -a ~/.bashrc



source ~/.bashrc
echo "RemoveIPC=no" | sudo tee -a /etc/systemd/logind.conf
sudo service systemd-logind restart
echo -e 'gpadmin hard core unlimited\ngpadmin hard nproc 131072\ngpadmin hard nofile 65536' | sudo tee -a /etc/security/limits.d/gpadmin-limits.conf


# clone src
ssh-keygen -F github.com || ssh-keyscan github.com >>~/.ssh/known_hosts
git clone --single-branch --branch cerebro git@github.com:makemebitter/madlib.git /local/madlib
git clone git@github.com:makemebitter/cerebro-greenplum.git /local/cerebro-greenplum
git clone https://github.com/makemebitter/theia-ide.git /local/theia

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
git checkout 1c280c0f2e657511a4be50866baaf2e8b4411cb7
# -DCMAKE_INSTALL_PREFIX=/usr/local/gpdb 
cmake -GNinja -H. -Bbuild 
set +e
# run twice for bypassing ccache issue, first run will create the needed files
sudo ninja install -C build
sudo ninja install -C build
set -e

# refresh dynamic libs
sudo ldconfig

# gpdb
sudo pip install cryptography==2.9.2;
# important missing dependency
sudo pip install lockfile;
cd /local/gpdb_src
# git checkout 5X_STABLE
git reset --hard HEAD
git checkout 6117a957007f1f2f402c0c2581e6078e4b284b41
./configure --with-perl --with-python --with-libxml --with-gssapi --prefix=/usr/local/gpdb
make -j
sudo make -j install

. /usr/local/gpdb/bin/generate-greenplum-path.sh
echo 'source /usr/local/gpdb/greenplum_path.sh' >> ~/.bashrc
source ~/.bashrc
sudo chown -R gpadmin:gpadmin /usr/local/gpdb
echo 'export MASTER_DATA_DIRECTORY=/mnt/gpdata_master/gpseg-1' >> /usr/local/gpdb/greenplum_path.sh
# important missing dependency
sudo pip install paramiko;


source /usr/local/gpdb/greenplum_path.sh
# madlib
sudo apt-get install -y libboost-all-dev
cd /local/madlib;
mkdir build;
cd build;
cmake ..;

set +e
# first time would fail due to boost and then it will download the correct one
make -j;
make -j;
set -e


# theia
cd /local/theia
bash install.sh download '/usr/bin/python3.7'
nohup theia start / --hostname=127.0.0.1 > /local/logs/theia.log 2>&1 &





# GPDB ppa use if above doen't work -––----------------------------------------
# sudo add-apt-repository -y ppa:greenplum/db
# sudo apt-get update
# sudo apt-get install -y greenplum-db-oss
# sudo chown -R gpadmin:gpadmin /opt/gpdb
# source /opt/gpdb/greenplum_path.sh
# -------––--------------------------------------------------------------------



echo "GPDB INSTALLATION FINISHED"
echo $PATH
source /usr/local/gpdb/greenplum_path.sh
echo $PATH
if [ "$duty" = "m" ]; then
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
            gpstart -a
            gpconfig -c gp_vmem_protect_limit -v 153600
            # gpconfig -c log_statement -v mod
            # gpconfig -c gp_resqueue_memory_policy -v auto
            gpconfig -c max_statement_mem -v 153600MB
            gpconfig -c statement_mem -v 15360MB
            gpstop -a
            gpstart -a
            echo $?
            set -e
            /local/madlib/build/src/bin/madpack -p greenplum -c gpadmin@master:5432/cerebro install

            break
        else
            echo "WAITING"
            sleep 5s
        fi
    done
    source ~/.bashrc
    source /usr/local/gpdb/greenplum_path.sh
    gpstop -a -M fast
    gpstart -a
    echo "GPDB INITIALIZATION FINISHED"    
fi
touch $TAG_PATH
echo "GPDB SCRIPT EXISTING"


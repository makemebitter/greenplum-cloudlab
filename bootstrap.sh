#!/bin/bash
duty=${1}
JUPYTER_PASSWORD=${2:-"root"}
PRIVATE_KEY=${3}
set -e
sudo apt-get update;
sudo apt-get install -y openssh-server openssh-client syslinux-utils python3-pip socat;
# docker
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io


# ------------------------- build from src ------------------------------------
# greenplum key
echo $PRIVATE_KEY > /local/gpdb_key
chmod 600 /local/gpdb_keys
# greenplum
git clone https://github.com/greenplum-db/gpdb.git  /local/gpdb_src
git clone https://github.com/greenplum-db/gporca.git /local/gporca
git clone https://github.com/greenplum-db/gp-xerces.git /local/gp-xerces
export DEBIAN_FRONTEND=noninteractive
sudo bash /local/gpdb_src/README.ubuntu.bash
echo /usr/local/lib | sudo tee -a  /etc/ld.so.conf
sudo ldconfig
cd /local
sudo bash gpdb_src/concourse/scripts/setup_gpadmin_user.bash
sudo bash -c 'cat >> /etc/sysctl.conf <<-EOF
kernel.shmmax = 500000000
kernel.shmmni = 4096
kernel.shmall = 4000000000
kernel.sem = 500 1024000 200 4096
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.ipv4.ip_local_port_range = 1025 65535
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.overcommit_memory = 2
EOF'

sudo bash -c 'cat >> /etc/security/limits.conf <<-EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072

EOF'

sudo bash -c 'cat >> /etc/ld.so.conf <<-EOF
/usr/local/libs

EOF'

# gp-xerces
cd /local/gp-xerces
mkdir build
cd build
../configure --prefix=/usr/local
sudo make
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
sudo make -j install
/usr/local/gpdb/bin/generate-greenplum-path.sh
source /usr/local/gpdb/greenplum_path.sh

# madlib
git clone https://github.com/apache/madlib.git /local/madlib;
cd /local/madlib;
mkdir build;
cd build;
cmake ..;
make -j;

# python
pip3 install -r /local/repository/requirements.txt;
# -----------------------------------------------------------------------------

# GPDB ppa ------------––------------------------------------------------------
# sudo add-apt-repository -y ppa:greenplum/db
# sudo apt-get update
# sudo apt-get install -y greenplum-db
# sudo bash /opt/greenplum-db-6.0.1/greenplum_path.sh
# -------––--------------------------------------------------------------------

# Spark ips configs
# ips=($(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}'))
# for ip in "${ips[@]}"
# do
#     if [[ $ip == *"10."* ]]; then
#         echo export LOCAL_IP=$ip >> ~/._bashrc;
#         LOCAL_IP=$ip
#     fi
# done


# master_ip=$(gethostip -d master);
# echo "export SPARK_MASTER_HOST=$master_ip" | sudo tee -a /usr/local/spark/conf/spark-env.sh;
# echo "export SPARK_LOCAL_IP=$LOCAL_IP" | sudo tee -a /usr/local/spark/conf/spark-env.sh;
# echo "export PYSPARK_PYTHON=python3.6" | sudo tee -a /usr/local/spark/conf/spark-env.sh;


# Jupyter extension configs
sudo /usr/local/bin/jupyter contrib nbextension install --system ;
sudo /usr/local/bin/jupyter nbextensions_configurator enable --system ;
sudo /usr/local/bin/jupyter nbextension enable code_prettify/code_prettify --system ;
sudo /usr/local/bin/jupyter nbextension enable execute_time/ExecuteTime --system ;
sudo /usr/local/bin/jupyter nbextension enable collapsible_headings/main --system ;
sudo /usr/local/bin/jupyter nbextension enable freeze/main --system ;
sudo /usr/local/bin/jupyter nbextension enable spellchecker/main --system ;

# Jupyter password
mkdir -p ~/.jupyter;
HASHED_PASSWORD=$(python3.6 -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))");
echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >~/.jupyter/jupyter_notebook_config.py;
echo "c.NotebookApp.open_browser = False" >>~/.jupyter/jupyter_notebook_config.py;




# Running Jupyter deamons
if [ "$duty" = "m" ]; then
	sudo nohup docker run --init -p 3000:3000 -v "/:/home/project:cached" theiaide/theia-python:next > /dev/null 2>&1 &
	sudo nohup jupyter notebook --no-browser --allow-root --ip 0.0.0.0 --notebook-dir=/ > /dev/null 2>&1 &


# elif [ "$duty" = "s" ]; then
# 	sudo bash /usr/local/spark/sbin/start-slave.sh $master_ip:7077
# 	sudo nohup socat TCP-LISTEN:8082,fork TCP:${LOCAL_IP}:8081 > /dev/null 2>&1 &	
# fi
echo "Bootstraping complete"


cp ~/._bashrc /local/.bashrc









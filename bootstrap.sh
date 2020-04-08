#!/bin/bash
set -e

duty=${1}
JUPYTER_PASSWORD=${2:-"root"}
PRIVATE_KEY=${3}
FILE_PATH=/local/gphost_list
echo "PRIVATE KEY"
echo "${PRIVATE_KEY}"


sudo apt-get update;
sudo apt-get install -y openssh-server openssh-client syslinux-utils python3-pip socat libffi-dev python-pip;
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
# docker
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo add-apt-repository -y \
#    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#    $(lsb_release -cs) \
#    stable"
# sudo apt-get update
# sudo apt-get -y install docker-ce docker-ce-cli containerd.io

# python 3.6
# sudo add-apt-repository ppa:deadsnakes/ppa
# sudo apt-get update
# sudo apt-get install python3.6 python3.6-venv
# curl https://bootstrap.pypa.io/get-pip.py | sudo python3.6


# --------------------- Check if every host online ----------------------------
awk 'NR>1 {print $NF}' /etc/hosts | grep -v 'master' > /local/gphost_list
if [ "$duty" = "m" ]; then
    readarray -t hosts < $FILE_PATH
    while true; do
        echo "Checking if other hosts online"
        all_done=true
        for host in "${hosts[@]}"; do
            if nc -w 2 -z $host 22 2>/dev/null; then
                echo "$host ✓"
            else
                echo "$host ✗"
                all_done=false
            fi
        done
        

        if [ "$all_done" = true ] ; then
            break
        else
            echo "WAITING"
            sleep 5s
        fi
    done
fi
# -----------------------------------------------------------------------------
# Get the extra filesystem otherwise no enough disk space
sudo /usr/local/etc/emulab/mkextrafs.pl /mnt
sudo mkdir /mnt/local
sudo rsync -av /local/ /mnt/local/
sudo rm -rvf /local/*
sudo mount -o bind /mnt/local /local
sudo mkdir /mnt/var.cache.apt.archives
sudo rsync -av /var/cache/apt/archives/ /mnt/var.cache.apt.archives/
sudo rm -rvf /var/cache/apt/archives/*
sudo mount -o bind /mnt/var.cache.apt.archives/ /var/cache/apt/archives/
# greenplum
# ------------------------- system settings -----------------------------------
git clone https://github.com/greenplum-db/gpdb.git  /local/gpdb_src
git clone https://github.com/greenplum-db/gporca.git /local/gporca
git clone https://github.com/greenplum-db/gp-xerces.git /local/gp-xerces
git clone https://github.com/apache/madlib.git /local/madlib
chmod 777 /local/gpdb_src /local/gporca /local/gp-xerces /local/madlib
export DEBIAN_FRONTEND=noninteractive
cd /local
sudo bash /local/gpdb_src/README.ubuntu.bash
echo /usr/local/lib | sudo tee -a  /etc/ld.so.conf
sudo ldconfig
sudo bash /local/gpdb_src/concourse/scripts/setup_gpadmin_user.bash
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

sudo usermod -aG sudo gpadmin
echo "gpadmin ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/gpadmin
# -----------------------------------------------------------------------------

# greenplum key
echo "${PRIVATE_KEY}" > /local/gpdb_key
chown gpadmin /local/gpdb_key
chmod 600 /local/gpdb_key
# cat ~/.ssh/authorized_keys >> /home/gpadmin/.ssh/authorized_keys
# echo >> /home/gpadmin/.ssh/authorized_keys
ssh-keygen -y -f /local/gpdb_key >> /home/gpadmin/.ssh/authorized_keys

chmod 777 /local/logs
chmod 666 -R /local/logs/*

sudo mkdir /gpdata
sudo chown gpadmin /gpdata
if [ "$duty" = "m" ]; then
  sudo mkdir /gpdata_master
  sudo chown gpadmin /gpdata_master
fi

# install madlib dependencies
echo "/usr/local/cuda/extras/CUPTI/lib64" | sudo tee -a /etc/ld.so.conf
sudo rm -rvf /usr/lib/python2.7/dist-packages/OpenSSL
sudo pip install -U pyopenssl
sudo pip install --upgrade pip
# Add NVIDIA package repositories
# Add HTTPS support for apt-key

sudo apt-get install -y gnupg-curl
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_10.0.130-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu1604_10.0.130-1_amd64.deb
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
sudo apt-get update
wget http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
sudo apt install -y ./nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
sudo apt-get update


# Install NVIDIA driver
# Issue with driver install requires creating /usr/lib/nvidia
sudo mkdir /usr/lib/nvidia
sudo apt-get install -y --no-install-recommends nvidia-410
# Reboot. Check that GPUs are visible using the command: nvidia-smi

# Install development and runtime libraries (~4GB)
sudo apt-get install -y --no-install-recommends \
    cuda-10-0 \
    libcudnn7=7.4.1.5-1+cuda10.0  \
    libcudnn7-dev=7.4.1.5-1+cuda10.0


# Install TensorRT. Requires that libcudnn7 is installed above.
sudo apt-get update && \
        sudo apt-get install nvinfer-runtime-trt-repo-ubuntu1604-5.0.2-ga-cuda10.0 \
        && sudo apt-get update \
        && sudo apt-get install -y --no-install-recommends libnvinfer5=5.0.2-1+cuda10.0 libnvinfer-dev=5.0.2-1+cuda10.0

sudo ldconfig




# compile, install, and run gpdb, compile and install madlib
sudo -H -u  gpadmin bash /local/repository/install_gpdb.sh ${duty}




# -----------------------------------------------------------------------------



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

# Running Jupyter deamons
if [ "$duty" = "m" ]; then
  # python
  pip3 install --upgrade six
  pip3 install -r /local/repository/requirements_master.txt;
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
  HASHED_PASSWORD=$(python3 -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))");
  echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >~/.jupyter/jupyter_notebook_config.py;
  echo "c.NotebookApp.open_browser = False" >>~/.jupyter/jupyter_notebook_config.py;
    sudo nohup docker run --init -p 3000:3000 -v "/:/home/project:cached" theiaide/theia-python:next > /dev/null 2>&1 &
    sudo nohup jupyter notebook --no-browser --allow-root --ip 0.0.0.0 --notebook-dir=/ > /dev/null 2>&1 &
fi

# elif [ "$duty" = "s" ]; then
#   gpssh-exkeys -f hostlist_singlenode
# fi
echo "Bootstraping complete"


cp ~/.bashrc /local/.bashrc
touch /local/SUCCESS









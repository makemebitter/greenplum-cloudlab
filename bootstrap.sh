#!/bin/bash
set -e

duty=${1}
JUPYTER_PASSWORD=${2:-"root"}
PRIVATE_KEY=${3}
FILE_PATH=/local/gphost_list
NFS_DIR=/mnt/nfs
CPU_LOG_DIR=$NFS_DIR/logs/cpu_logs
GPU_LOG_DIR=$NFS_DIR/logs/gpu_logs
PROJECT_USER=gpadmin
echo "PRIVATE KEY"
echo "${PRIVATE_KEY}"



sudo apt-get update;
sudo apt-get install -y openssh-server openssh-client syslinux-utils python3-pip socat libffi-dev python-pip htop;
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common


# python 3.7
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get install -y python3.7 python3.7-venv python3.7-dev
# curl https://bootstrap.pypa.io/get-pip.py | sudo python3.7
# curl https://bootstrap.pypa.io/get-pip.py | sudo python


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

# sudo mkdir /mnt/local
# chmod 777 -R /local /mnt
# sudo rm -rvf /local/*

sudo mkdir /mnt/home
sudo rsync -av /home/ /mnt/home/
sudo rm -rvf /home/*
sudo mount -o bind /mnt/home/ /home/

sudo mkdir /mnt/tmp
sudo rsync -av /tmp/ /mnt/tmp/
sudo rm -rvf /tmp/*
sudo mount -o bind /mnt/tmp/ /tmp/
sudo chmod 1777 /tmp


sudo mkdir /mnt/var.lib
sudo rsync -av /var/lib/ /mnt/var.lib/
sudo rm -rvf /var/lib/*
sudo mount -o bind /mnt/var.lib/ /var/lib/

sudo mkdir /mnt/var.cache
sudo rsync -av /var/cache/ /mnt/var.cache/
sudo rm -rvf /var/cache/*
sudo mount -o bind /mnt/var.cache/ /var/cache/

# Don't use
sudo mkdir /mnt/usr.local
sudo rsync -av /usr/local/ /mnt/usr.local/
sudo rm -rvf /usr/local/*
sudo mount -o bind /mnt/usr.local/ /usr/local/


sudo dpkg --configure -a
# greenplum
# ------------------------- system settings -----------------------------------
git clone https://github.com/greenplum-db/gpdb.git  /local/gpdb_src
cd /local/gpdb_src
git checkout 6117a957007f1f2f402c0c2581e6078e4b284b41
git clone https://github.com/greenplum-db/gporca.git /local/gporca
git clone https://github.com/greenplum-db/gp-xerces.git /local/gp-xerces
git clone --single-branch --branch cerebro https://github.com/makemebitter/madlib.git /local/madlib
git clone https://github.com/makemebitter/cerebro-greenplum.git /local/cerebro-greenplum
sudo chmod 777 -R  /local/gpdb_src /local/gporca /local/gp-xerces /local/madlib /local/cerebro-greenplum
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
ssh-keygen -y -f /local/gpdb_key >> /home/gpadmin/.ssh/authorized_keys


sudo mkdir /mnt/gpdata
sudo chown gpadmin /mnt/gpdata
if [ "$duty" = "m" ]; then
  sudo mkdir /mnt/gpdata_master
  sudo chown gpadmin /mnt/gpdata_master
fi

# install madlib dependencies
echo "/usr/local/cuda/extras/CUPTI/lib64" | sudo tee -a /etc/ld.so.conf
sudo rm -rvf /usr/lib/python2.7/dist-packages/OpenSSL
sudo pip install -U pyopenssl
sudo pip install --upgrade pip


# CUDA 10.0
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


# # CUDA 10.1
# Add NVIDIA package repositories
# Add HTTPS support for apt-key
# sudo apt-get -y install gnupg-curl
# wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_10.1.243-1_amd64.deb
# sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
# sudo dpkg -i cuda-repo-ubuntu1604_10.1.243-1_amd64.deb
# sudo apt-get update
# wget http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
# sudo apt install -y ./nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
# sudo apt-get update

# # Install NVIDIA driver
# # Issue with driver install requires creating /usr/lib/nvidia
# sudo mkdir /usr/lib/nvidia
# sudo apt-get install -y --no-install-recommends nvidia-440
# # Reboot. Check that GPUs are visible using the command: nvidia-smi

# # Install development and runtime libraries (~4GB)
# sudo apt-get install -y --no-install-recommends \
#     cuda-10-1 \
#     libcudnn7=7.6.4.38-1+cuda10.1  \
#     libcudnn7-dev=7.6.4.38-1+cuda10.1


# # Install TensorRT. Requires that libcudnn7 is installed above.
# sudo apt-get install -y --no-install-recommends \
#     libnvinfer6=6.0.1-1+cuda10.1 \
#     libnvinfer-dev=6.0.1-1+cuda10.1 \
#     libnvinfer-plugin6=6.0.1-1+cuda10.1


sudo ldconfig


sudo pip install -r /local/repository/requirements_madlib.txt



# compile, install, and run gpdb, compile and install madlib
sudo -H -u $PROJECT_USER /local/repository/install_gpdb.sh ${duty}




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

# NFS

sudo apt-get -y install nfs-kernel-server
sudo apt-get -y install nfs-common
sudo mkdir $NFS_DIR
sudo chmod 777 -R $NFS_DIR;
# Running Jupyter deamons
if [ "$duty" = "m" ]; then
    echo "$NFS_DIR  *(rw,sync,crossmnt,no_root_squash,crossmnt)" | sudo tee -a  /etc/exports
    sudo /etc/init.d/nfs-kernel-server restart
    # python
    sudo python3.7 -m pip install --upgrade six
    sudo python3.7 -m pip install -r /local/repository/requirements_master.txt;
    # Jupyter extension configs
    sudo python3.7 -m jupyter contrib nbextension install --system ;
    sudo python3.7 -m jupyter nbextensions_configurator enable --system ;
    sudo python3.7 -m jupyter nbextension enable code_prettify/code_prettify --system ;
    sudo python3.7 -m jupyter nbextension enable execute_time/ExecuteTime --system ;
    sudo python3.7 -m jupyter nbextension enable collapsible_headings/main --system ;
    sudo python3.7 -m jupyter nbextension enable freeze/main --system ;
    sudo python3.7 -m jupyter nbextension enable spellchecker/main --system ;
    # docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
    sudo apt-get update
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
    echo 'DOCKER_OPTS="-g /mnt"' | sudo tee -a /etc/default/docker
    sudo service docker stop
    sudo service docker start
    sudo mkdir /mnt/var.lib.docker
    sudo rsync -av /var/lib/docker/ /mnt/var.lib.docker/
    sudo rm -rvf /var/lib/docker/*
    sudo mount -o bind /mnt/var.lib.docker/ /var/lib/docker/
    # Jupyter password
    mkdir -p ~/.jupyter;
    HASHED_PASSWORD=$(python3.7 -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))");
    echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >~/.jupyter/jupyter_notebook_config.py;
    echo "c.NotebookApp.open_browser = False" >>~/.jupyter/jupyter_notebook_config.py;
    sudo nohup docker run --init -p 3000:3000 -v "/:/home/project:cached" theiaide/theia-python:next > /local/logs/theia.log 2>&1 &
    sudo nohup jupyter notebook --no-browser --allow-root --ip 0.0.0.0 --notebook-dir=/ > /local/logs/jupyter.log 2>&1 &
elif [ "$duty" = "s" ]; then
    # For workers
    # Mount nfs
    n=0
    until [ $n -ge 1000 ]
    do
       sudo mount master:$NFS_DIR $NFS_DIR && break  # substitute your command here
       n=$[$n+1]
       sleep 15
    done
    
fi
echo 'export WORKER_NAME=$(cat /proc/sys/kernel/hostname | cut -d'.' -f1)' | sudo tee -a "/home/$PROJECT_USER/.bashrc"
echo 'export WORKER_NUMBER=$(sed -n -e 's/^.*worker//p' <<<"$WORKER_NAME")' | sudo tee -a "/home/$PROJECT_USER/.bashrc"
source "/home/$PROJECT_USER/.bashrc";


echo $WORKER_NAME
echo $WORKER_NUMBER

sudo -H -u $PROJECT_USER nohup bash /local/cerebro-greenplum/bin/cpu_logger.sh $CPU_LOG_DIR &
sudo -H -u $PROJECT_USER nohup bash /local/cerebro-greenplum/bin/gpu_logger.sh $GPU_LOG_DIR &
sudo chmod -R 777 $NFS_DIR

echo "Bootstraping complete"


cp ~/.bashrc /local/.bashrc
touch /local/ALL_SUCCESS









TRAIN_PATH=/mnt/imagenet/train
VALID_PATH=/mnt/imagenet/valid

mkdir -p $TRAIN_PATH $VALID_PATH
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/train/train_$i.h5" --create-dirs -o $TRAIN_PATH/train_$i.h5
done; \
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/valid/valid_$i.h5" --create-dirs -o $VALID_PATH/valid_$i.h5
done



# (on all)
wget -O /home/gpadmin/.screenrc https://raw.githubusercontent.com/makemebitter/greenplum-cloudlab/master/.screenrc 
# Download gdrive-linux-x64 (on master)
wget https://github.com/makemebitter/gdrive-cli-builder/releases/download/1.0/gdrive-linux-x64
sudo chmod +x gdrive-linux-x64
sudo mv gdrive-linux-x64 /usr/local/bin/gdrive
gdrive about
sudo chmod -R 777 /mnt/nfs
# gdrive upload -r -p 1Lp-o4utwAMsGkMfQhz0M0YUlfuvPxB-N /mnt/nfs/imagenet

gdrive upload -r -p 18koUxroISe0raQx5AqrH9Mxr4Ylch-57 /mnt/nfs/hdd/imagenet
gdrive upload -r -p 1uB_OJXYrS82hqjzMWiRlW6BoDHuWh1iB /mnt/nfs/hdd/cerebro_spark_tmp

gdrive upload -p 1iidZSmxqCKTbDtudllenXRAASxMlUhvz cerebro_ds_logs.tar



# Download imagenet (on master)

gdrive download -r --path /mnt/nfs 1zLryoR1CjSQI9gDIdrGux6Bbm2zeAZr5 
gdrive download -r --path /mnt/nfs/hdd 1zLryoR1CjSQI9gDIdrGux6Bbm2zeAZr5 

#imagenet, copy to local (on workers)
mkdir -p /mnt/imagenet/{train,valid}
cp /mnt/nfs/imagenet/valid/valid_$WORKER_NUMBER.h5 /mnt/imagenet/valid;\
cp /mnt/nfs/imagenet/train/train_$WORKER_NUMBER.h5 /mnt/imagenet/train


# Criteo preprocessing
# python2 preprocessing_criteo.py --data_root '/mnt/hdd/criteo' --log_root '/mnt/nfs/logs' --nfs_root '/mnt/nfs/models/data_share/criteo/tfrecords'


# Partition hdd disk (on all), check if sdb is actually the hdd
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk /dev/sdb
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
    # default - end at ending of disk
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF
sudo mkfs.ext3 /dev/sdb1

# create swap (for scalability)
swap_file=/mnt/hdd/swapfile
sudo dd if=/dev/zero of=$swap_file bs=1024 count=314572800
sudo chmod 600 $swap_file
sudo mkswap $swap_file
sudo swapon $swap_file
sudo swapon --show
sudo free -h

# on master
mkdir -p /mnt/nfs/hdd
sudo mount /dev/sdb1 /mnt/nfs/hdd
sudo chown gpadmin /mnt/nfs/hdd
# on worker
mkdir -p /mnt/hdd
sudo mount /dev/sdb1 /mnt/hdd
sudo chown gpadmin /mnt/hdd

# Download criteo data (on master)
sudo chmod -R 777 /mnt/nfs
mkdir -p /mnt/nfs/hdd/criteo
gdrive download -r --path /mnt/nfs/hdd/criteo 1c7UapUWys474HhbNQp5iCOEMsbJn4O_2 

# copy data to local (on workers)
sudo chmod -R 777 /mnt/hdd
mkdir -p /mnt/hdd/criteo/{train,valid}
cp /mnt/nfs/hdd/criteo/npy/valid/valid_$WORKER_NUMBER.npy /mnt/hdd/criteo/valid;\
cp /mnt/nfs/hdd/criteo/npy/train/train_$WORKER_NUMBER.npy /mnt/hdd/criteo/train

# run cerebro standalone 
# cerebro standalone
# (on everything)
cd /local
git clone --single-branch --branch data_pipeline_test git@github.com:scnakandala/cerebro.git
export CEREBRO_LOG_DIR=/mnt/nfs/logs/run_logs/cerebro_run_logs
mkdir $CEREBRO_LOG_DIR
# (on workers)
unset PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/local:/local/cerebro-greenplum"
git pull; bash /local/cerebro/bin/cerebro_worker.sh restart $WORKER_NAME 8000 $CEREBRO_LOG_DIR; tail -f $CEREBRO_LOG_DIR/cerebro_log_$WORKER_NAME.log


# recompile, sync, and reinstall madlib
bash /local/madlib/tool/cluster_install.sh
# dev-check
/local/madlib/build/src/bin/madpack dev-check -t deep_learning/madlib_keras_automl -p greenplum -c /cerebro

# daily commit
if nvidia-smi ; then
    export PUR='gpu'
else
    export PUR='cpu'
fi
echo $PUR
rsync -avr /mnt/nfs/logs/ /local/cerebro-greenplum/logs/all_logs_${PUR}_2021feb
cd /local/cerebro-greenplum
git pull
git add . ; git commit -m 'update'; git push



# setup spark
cd /local
git clone https://github.com/makemebitter/spark-cloudlab.git


# 

sudo bash -c 'cat >> ~/.bashrc <<-EOF
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, dont overwrite it

# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF'

source ~/.bashrc

wget -O ~/.screenrc https://raw.githubusercontent.com/makemebitter/greenplum-cloudlab/master/.screenrc 





# change to cerebro-spark
export LD_LIBRARY_PATH=/usr/local/gpdb/lib:/usr/local/cuda/extras/CUPTI/lib64
# CUDA 10.1
# Add NVIDIA package repositories
# Add HTTPS support for apt-key

# execute one by one
sudo apt-get --purge -y remove 'cuda*';
sudo apt-get --purge -y remove 'nvidia*';
sudo apt-get --purge -y remove 'libnvidia*';
sudo apt autoremove

sudo apt-get -y install gnupg-curl
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_10.1.243-1_amd64.deb
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
sudo dpkg -i cuda-repo-ubuntu1604_10.1.243-1_amd64.deb
sudo apt-get update
wget http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
sudo apt install -y ./nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
sudo apt-get update

echo "/usr/local/cuda-10.2/lib64" | sudo tee -a /etc/ld.so.conf


# Install NVIDIA driver
# Issue with driver install requires creating /usr/lib/nvidia
sudo mkdir /usr/lib/nvidia
sudo apt-get install -y --no-install-recommends nvidia-440
# Reboot. Check that GPUs are visible using the command: nvidia-smi

#  don't copy all
# Install development and runtime libraries (~4GB)
sudo apt-get install -y --no-install-recommends \
    cuda-10-1 \
    libcudnn7=7.6.4.38-1+cuda10.1  \
    libcudnn7-dev=7.6.4.38-1+cuda10.1


# Install TensorRT. Requires that libcudnn7 is installed above.
sudo apt-get install -y --no-install-recommends \
    libnvinfer6=6.0.1-1+cuda10.1 \
    libnvinfer-dev=6.0.1-1+cuda10.1 \
    libnvinfer-plugin6=6.0.1-1+cuda10.1

sudo ldconfig

sudo python3.7 -m pip install --upgrade pip
sudo python3.7 -m pip install cerebro-dl
sudo python3.7 -m pip install petastorm==0.9.0
sudo python3.7 -m pip install pyarrow==0.16.0
sudo python3.7 -m pip uninstall tensorflow-gpu
sudo python3.7 -m pip install tensorflow==2.2.0



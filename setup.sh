TRAIN_PATH=/mnt/imagenet/train
VALID_PATH=/mnt/imagenet/valid

mkdir -p $TRAIN_PATH $VALID_PATH
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/train/train_$i.h5" --create-dirs -o $TRAIN_PATH/train_$i.h5
done; \
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/valid/valid_$i.h5" --create-dirs -o $VALID_PATH/valid_$i.h5
done




wget -O /home/gpadmin/.screenrc https://raw.githubusercontent.com/makemebitter/greenplum-cloudlab/master/.screenrc 
# Download gdrive-linux-x64
wget https://github.com/makemebitter/gdrive-cli-builder/releases/download/1.0/gdrive-linux-x64
sudo chmod +x gdrive-linux-x64
sudo mv gdrive-linux-x64 /usr/local/bin/gdrive
gdrive about
# gdrive upload -r -p 1Lp-o4utwAMsGkMfQhz0M0YUlfuvPxB-N /mnt/nfs/imagenet



# Download imagenet
sudo chmod -R 777 /mnt/nfs
gdrive download -r --path /mnt/nfs 1zLryoR1CjSQI9gDIdrGux6Bbm2zeAZr5 



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

# on master
mkdir -p /mnt/nfs/hdd
sudo mount /dev/sdb1 /mnt/nfs/hdd
# on worker
mkdir -p /mnt/hdd
sudo mount /dev/sdb1 /mnt/hdd

# Download criteo data (on master)
sudo chmod -R 777 /mnt/nfs
mkdir -p /mnt/nfs/hdd/criteo
gdrive download -r --path /mnt/nfs/hdd/criteo 1c7UapUWys474HhbNQp5iCOEMsbJn4O_2 

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
bash /local/cerebro/bin/cerebro_worker.sh stop
bash /local/cerebro/bin/cerebro_worker.sh stop
bash /local/cerebro/bin/cerebro_worker.sh start $WORKER_NAME 8000 $CEREBRO_LOG_DIR &
tail -f /mnt/nfs/logs/run_logs/cerebro_run_logs/cerebro_log_$WORKER_NAME.log

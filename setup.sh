TRAIN_PATH=/mnt/imagenet/train
VALID_PATH=/mnt/imagenet/valid

mkdir -p $TRAIN_PATH $VALID_PATH
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/train/train_$i.h5" --create-dirs -o $TRAIN_PATH/train_$i.h5
done; \
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/valid/valid_$i.h5" --create-dirs -o $VALID_PATH/valid_$i.h5
done

# cerebro standalone
export CEREBRO_LOG_DIR=/mnt/nfs/logs/run_logs/cerebro_run_logs
mkdir $CEREBRO_LOG_DIR
unset PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/local:/local/cerebro-greenplum/code"
bash /local/cerebro/bin/cerebro_worker.sh start $WORKER_NAME 8000 $CEREBRO_LOG_DIR &

git clone https://github.com/nurdtechie98/drive-cli.git
# paste oauth client secret
sudo python3.7 -m pip install -e .
drive --remote login




# sudo apt-get -y install git cmake build-essential libgcrypt11-dev libyajl-dev libboost-all-dev libcurl4-openssl-dev libexpat1-dev libcppunit-dev binutils-dev pkg-config zlib1g-dev
# git clone https://github.com/vitalif/grive2
# cd grive2
# dpkg-buildpackage -j4
# cd ..
# sudo apt install grive_0.5.1+git20160731_amd64.deb
# cd ~
# mkdir google-drive
# cd google-drive


# wget https://github.com/makemebitter/gdrive-cli-builder/suites/1300909639/artifacts/20413740

# Download gdrive-linux-x64
sudo chmod +x gdrive-linux-x64
sudo mv gdrive-linux-x64 /usr/local/bin/gdrive
gdrive about
# gdrive upload -r -p 1Lp-o4utwAMsGkMfQhz0M0YUlfuvPxB-N /mnt/nfs/imagenet



# Criteo preprocessing
python2 preprocessing_criteo.py --data_root '/mnt/criteo' --log_root '/mnt/nfs/logs' --nfs_root '/mnt/nfs/models/data_share/criteo/tfrecords'
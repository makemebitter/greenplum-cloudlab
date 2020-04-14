TRAIN_PATH=/mnt/imagenet/train
VALID_PATH=/mnt/imagenet/valid

mkdir -p $TRAIN_PATH $VALID_PATH
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/train/train_$i.h5" --create-dirs -o $TRAIN_PATH/train_$i.h5
done; \
for i in $(seq 0 7); do
  curl "http://supun.ucsd.edu/cerebro/data/imagenet/valid/valid_$i.h5" --create-dirs -o $VALID_PATH/valid_$i.h5
done
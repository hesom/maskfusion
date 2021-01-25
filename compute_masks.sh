optional_args=${@:3}
xhost +local:root; \
docker run -it --gpus all \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix:rw \
-v $1:/data/images/ \
maskfusion \
sh -c "mkdir /data/masks/ && cd /opt/MaskFusion/Core/Segmentation/MaskRCNN/ && ./offline_runner.py -i /data/images/ -o /data/masks/ ${optional_args} && cd /opt/MaskFusion/build/GUI" &&\

docker cp $(docker ps -alq):/data/masks $2
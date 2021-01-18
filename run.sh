xhost +local:root; \
docker run -it --gpus all \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix:rw \
-v $1:/data/dataset.klg \
maskfusion \
MaskFusion -l /data/dataset.klg ${@:2}

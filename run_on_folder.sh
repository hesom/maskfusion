optional_args=${@:2}
xhost +local:root; \
docker run -it --gpus all \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix:rw \
-v $1:/data/images/ \
maskfusion \
MaskFusion -dir /data/images/ -depthdir /data/images/ -maskdir /data/images/ -exportdir /data/export ${optional_args}

docker cp $(docker ps -alq):/data/export/ ./export/
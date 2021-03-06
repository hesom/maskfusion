optional_args=${@:2}
xhost +local:root; \
docker run -it --gpus all \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix:rw \
-v $(readlink -f $1):/data/dataset.klg \
maskfusion \
MaskFusion -l /data/dataset.klg -exportdir /data/export ${optional_args}

docker cp $(docker ps -alq):/data/export/ ./export/
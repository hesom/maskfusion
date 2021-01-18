# Build libglvnd
FROM ubuntu:16.04 as glvnd

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        make \
        automake \
        autoconf \
        libtool \
        pkg-config \
        python \
        libxext-dev \
        libx11-dev \
        x11proto-gl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/libglvnd
RUN git clone --branch=v1.0.0 https://github.com/NVIDIA/libglvnd.git . && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib/x86_64-linux-gnu && \
    make -j"$(nproc)" install-strip && \
    find /usr/local/lib/x86_64-linux-gnu -type f -name 'lib*.la' -delete

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        gcc-multilib \
        libxext-dev:i386 \
        libx11-dev:i386 && \
    rm -rf /var/lib/apt/lists/*

# 32-bit libraries
RUN make distclean && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib/i386-linux-gnu --host=i386-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32" && \
    make -j"$(nproc)" install-strip && \
    find /usr/local/lib/i386-linux-gnu -type f -name 'lib*.la' -delete


FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04

COPY --from=glvnd /usr/local/lib/x86_64-linux-gnu /usr/local/lib/x86_64-linux-gnu
COPY --from=glvnd /usr/local/lib/i386-linux-gnu /usr/local/lib/i386-linux-gnu

#COPY 10_nvidia.json /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json

RUN echo '/usr/local/lib/x86_64-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    echo '/usr/local/lib/i386-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    ldconfig

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        libxau6 libxau6:i386 \
        libxdmcp6 libxdmcp6:i386 \
        libxcb1 libxcb1:i386 \
        libxext6 libxext6:i386 \
        libx11-6 libx11-6:i386 && \
    rm -rf /var/lib/apt/lists/*

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES \
        ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
        ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics,compat32,utility,display

# Required for non-glvnd setups.
ENV LD_LIBRARY_PATH /usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

run apt-get update && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y wget software-properties-common \
        build-essential \
        freeglut3-dev \
        git \
        gcc \
        g++ \
        cmake \
        libeigen3-dev \
        libglew-dev \
        libjpeg-dev \
        libsuitesparse-dev \
        libudev-dev \
        libusb-1.0-0-dev \
        openjdk-8-jdk \
        unzip \
        zlib1g-dev \
        cython3 \
        libboost-all-dev \
        libfreetype6-dev \
        openssl \
        libssl-dev \
        python3-pip \
        python3-venv \
        python3-tk

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 10000
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10000

WORKDIR /opt/venv
RUN pip3 install --upgrade pip
RUN pip3 install virtualenv
RUN virtualenv venv
ENV PATH=/opt/venv/venv/bin/:${PATH}
RUN . /opt/venv/venv/bin/activate && pip install pip --upgrade && pip install tensorflow-gpu==1.8.0 \
    && pip install scikit-image && pip install keras && pip install IPython \
    && pip install h5py && pip install cython && pip install imgaug \
    && pip install opencv-python && pip install pytoml \
    && pip install keras==2.1.5 \
    && ln -s `python -c "import numpy as np; print(np.__path__[0])"`/core/include/numpy Core/Segmentation/MaskRCNN || true

# build cmake from source
#WORKDIR /opt/cmake
#RUN wget https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3.tar.gz && tar -zxvf cmake-3.17.3.tar.gz
#RUN cd cmake-3.17.3 && ./bootstrap && make -j8 && make install

WORKDIR /opt/MaskFusion/deps

#build opencv
RUN git clone --branch 3.4.1 --depth=1 https://github.com/opencv/opencv.git &&\
    cd opencv && \
    mkdir -p build && \
    cd build && \
    cmake -E env CXXFLAGS="-w" cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="`pwd`/../install" \
      \
      `# OpenCV: (building is not possible when DBUILD_opencv_video/_videoio is OFF?)` \
      -DWITH_CUDA=OFF  \
    -DBUILD_DOCS=OFF  \
    -DBUILD_PACKAGE=OFF \
    -DBUILD_TESTS=OFF  \
    -DBUILD_PERF_TESTS=OFF  \
    -DBUILD_opencv_apps=OFF \
    -DBUILD_opencv_calib3d=OFF  \
    -DBUILD_opencv_cudaoptflow=OFF  \
    -DBUILD_opencv_dnn=OFF  \
    -DBUILD_opencv_dnn_BUILD_TORCH_IMPORTER=OFF  \
    -DBUILD_opencv_features2d=OFF \
    -DBUILD_opencv_flann=OFF \
    -DBUILD_opencv_java=OFF  \
    -DBUILD_opencv_objdetect=OFF  \
    -DBUILD_opencv_python2=OFF  \
    -DBUILD_opencv_python3=OFF  \
    -DBUILD_opencv_photo=OFF \
    -DBUILD_opencv_stitching=OFF  \
    -DBUILD_opencv_superres=OFF  \
    -DBUILD_opencv_shape=OFF  \
    -DBUILD_opencv_videostab=OFF \
    -DBUILD_PROTOBUF=OFF \
    -DWITH_1394=OFF  \
    -DWITH_GSTREAMER=OFF  \
    -DWITH_GPHOTO2=OFF  \
    -DWITH_MATLAB=OFF  \
    -DWITH_NVCUVID=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_OPENCLAMDBLAS=OFF \
    -DWITH_OPENCLAMDFFT=OFF \
    -DWITH_TIFF=OFF  \
    -DWITH_VTK=OFF  \
    -DWITH_WEBP=OFF  \
      .. && \
    make -j8 && \
    make install

ARG OpenCV_DIR=/opt/MaskFusion/deps/opencv/build

#build boost
RUN wget -O boost_1_62_0.tar.bz2 https://sourceforge.net/projects/boost/files/boost/1.62.0/boost_1_62_0.tar.bz2/download && \
    tar -xjf boost_1_62_0.tar.bz2 && \
    rm boost_1_62_0.tar.bz2 && \
    cd boost_1_62_0 && \
    mkdir -p ../boost && \
    ./bootstrap.sh --prefix=../boost && \
    ./b2 --prefix=../boost --with-filesystem install > /dev/null && \
    cd .. && \
    rm -r boost_1_62_0

ARG BOOST_ROOT=/opt/MaskFusion/deps/boost


#build Pangolin
RUN git clone https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && \
    mkdir build && cd build && \
    cmake ../ -DAVFORMAT_INCLUDE_DIR="" -DCPP11_NO_BOOST=ON && make -j8
ARG Pangolin_DIR=/opt/MaskFusion/deps/Pangolin/build

#build OpenNI2
RUN git clone https://github.com/occipital/OpenNI2.git; \
    cd OpenNI2; \
    make -j8

#build freetype-gl-cpp
RUN git clone --depth=1 --recurse-submodules https://github.com/martinruenz/freetype-gl-cpp.git && \
    cd freetype-gl-cpp && \
    mkdir -p build && \
    cd build && \
    cmake -DBUILD_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX="`pwd`/../install" -DCMAKE_BUILD_TYPE=Release .. &&\
    make -j8 && make install

# build densecrf
RUN git clone --depth=1 https://github.com/martinruenz/densecrf.git && cd densecrf && \
    mkdir -p build && \
    cd build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -fPIC" .. && \
    make -j8

# build gSLICr, see: http://www.robots.ox.ac.uk/~victor/gslicr/
RUN git clone https://github.com/carlren/gSLICr.git && cd gSLICr &&\
    mkdir -p build && cd build && \
    cmake \
        -DOpenCV_DIR="${OpenCV_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCUDA_HOST_COMPILER=/usr/bin/gcc \
        -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
        -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -D_FORCE_INLINES" .. && \
    make -j8

# Prepare MaskRCNN
RUN . /opt/venv/venv/bin/activate && git clone --depth=1 https://github.com/matterport/Mask_RCNN.git && \
    git clone --depth=1 https://github.com/waleedka/coco.git && \
    cd coco/PythonAPI && python setup.py build_ext --inplace && rm -rf build && python setup.py build_ext install && \
    cd ../.. && \
    cd Mask_RCNN && mkdir -p data && cd data && \
    wget --no-clobber https://github.com/matterport/Mask_RCNN/releases/download/v1.0/mask_rcnn_coco.h5

RUN git clone --depth=1 --branch v2.4.0 https://github.com/ToruNiina/toml11.git

WORKDIR /opt/MaskFusion/

COPY . /opt/MaskFusion/
RUN ln -s `python -c "import numpy as np; print(np.__path__[0])"`/core/include/numpy Core/Segmentation/MaskRCNN || true

RUN mkdir -p build && cd build && \
    cmake \
        -DBOOST_ROOT="${BOOST_ROOT}" \
        -DOpenCV_DIR="${OpenCV_DIR}" \
        -DPangolin_DIR="${Pangolin_DIR}" \
        -DMASKFUSION_PYTHON_VE_PATH=/opt/venv/venv \
        -DMASKFUSION_MASK_RCNN_DIR=/opt/MaskFusion/deps/Mask_RCNN \
        -DCUDA_HOST_COMPILER=/usr/bin/gcc \
        -DWITH_FREENECT2=OFF \
         .. && \
    make -j8

WORKDIR /opt/MaskFusion/build/GUI
ENV PATH=/opt/MaskFusion/build/GUI:${PATH}
FROM ubuntu:20.04

# Set environment variable to noninteractive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages
RUN apt-get update && apt-get install -y \
    build-essential \
    sudo \
    apt-utils \
    iputils-ping \
    net-tools \
    wget \
    nano \
    python3-pip \
    pciutils \
    curl \
    git \
    cmake \
    software-properties-common \
    sysvbanner \
    figlet

# Install CUDA 11.8 
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin && \
    mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600 && \
    wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb && \
    dpkg -i cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb && \
    cp /var/cuda-repo-ubuntu2004-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/ && \
    apt-get update && \
    apt-get -y install cuda 

# Set the environment variable for CUDA 11.8
ENV PATH=/usr/local/cuda-11.8/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH

# Add deadsnakes PPA for Python 3.8, install Python 3.8 and set as default
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y python3.8 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 && \
    ln -sf /usr/bin/python3.8 /usr/bin/python && \
    wget https://bootstrap.pypa.io/get-pip.py && \
    python3.8 get-pip.py && \
    ln -s /usr/bin/pip3 /usr/bin/pip && \
    rm get-pip.py

RUN pip install boxmot

# Install PyTorch with CUDA 11.8 support
# RUN pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118

# Create a user with the specified UID
ARG USER_ID
ARG USER_NAME
ARG GROUP_ID
ARG GROUP_NAME
ARG WORKSPACE

RUN groupadd -g $GROUP_ID $GROUP_NAME \
    && useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USER_NAME && \
    echo "$USER_NAME:$USER_NAME" | chpasswd && adduser $USER_NAME sudo

# Create a new workspace inside the container and set permissions
RUN mkdir -p /$WORKSPACE /data && \
    chown -R $USER_ID:$GROUP_ID /$WORKSPACE /data

# Set the working directory
WORKDIR /$WORKSPACE

# Switch to the new user
USER $USER_ID

RUN export PATH=$PATH:/home/$USER_NAME/.local/bin && \
    echo "export PATH=$PATH:/home/$USER_NAME/.local/bin" >> /home/$USER_NAME/.bashrc

# Add the figlet command to the bashrc to display a welcome message
RUN echo "figlet -f slant 'Welcome to the Docker container!'" >> ~/.bashrc

# Install additional needed packages
RUN pip install numpy==1.23.5 && \
    pip install opencv_python && \
    pip install loguru && \
    pip install tqdm && \
    pip install Pillow && \
    pip install thop && \
    pip install ninja && \
    pip install tabulate && \
    pip install tensorboard && \
    pip install lap && \
    pip install motmetrics && \
    pip install filterpy && \
    pip install h5py && \
    pip install onnx==1.8.1 && \
    pip install onnxruntime==1.8.0 && \
    pip install onnx-simplifier==0.3.5 && \
    pip install cython_bbox

# RUN python setup.py develop --user

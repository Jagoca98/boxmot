FROM ubuntu:22.04

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
    python3-distutils \
    python3-pip \
    pciutils \
    curl \
    git \
    cmake \
    libgl1 \
    software-properties-common \
    sysvbanner \
    figlet

# Install CUDA 11.8 
RUN wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run && \
    sh cuda_11.8.0_520.61.05_linux.run --silent --toolkit \
    && rm cuda_11.8.0_520.61.05_linux.run

# Set the environment variable for CUDA 11.8
ENV PATH=/usr/local/cuda-11.8/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH

# Install Python 3.10 and pip
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.10 python3.10-distutils python3.10-venv curl && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.10 get-pip.py && \
    ln -sf /usr/local/bin/pip3 /usr/bin/pip && \
    rm get-pip.py

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
    chown -R $USER_ID:$GROUP_ID /$WORKSPACE /data -R

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
    pip install protobuf==3.20.3

USER root

COPY ./boxmot/boxmot /dependencies/boxmot

RUN chown -R $USER_ID:$GROUP_ID /dependencies/boxmot && \
    cd /dependencies/boxmot && \
    python3 -m pip install --user setuptools==78.1.0 && \
    pip install -e .

USER $USER_ID
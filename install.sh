#!/bin/bash
echo "This script will reboot your computer at the end"

function check_installed () {
    REQUIRED_PKG=$1
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    echo Checking for $REQUIRED_PKG: $PKG_OK
    if [ "" = "$PKG_OK" ]; then
        echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
        sudo apt-get --yes install $REQUIRED_PKG
    fi
}

# check sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
apt-get update

# check git install
check_installed "git"

# check python 
check_installed "python3"

#install pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py --user

# check ipv4 address
myIP=$(hostname -I)
ipArr=($myIP)
myIP=${ipArr[0]}
echo "export LOCALIP=$myIP" >> ~/.bashrc

# install ansible
python3 -m pip install --user ansible

# install docker prerequisites 
apt-get --yes remove docker docker-engine docker.io containerd runc
apt-get --yes install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# download docker keys
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# download nvidia prequisites 
apt-get install linux-headers-$(uname -r)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-keyring_1.0-1_all.deb
dpkg -i cuda-keyring_1.0-1_all.deb

# install cuda container keys
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# install GPU Drivers
apt-get -y install cuda-drivers

# install CUDA
apt-get -y install cuda
# add cuda to path
export PATH=/usr/local/cuda-11.7/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-11.7/lib64 ${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

# install cuda container 
apt-get install -y nvidia-docker2
systemctl restart docker

# install gitlab runner 
# Not sure this will allow you to use docker executor
# Download the binary for your system
curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

# Give it permission to execute
chmod +x /usr/local/bin/gitlab-runner

# Create a GitLab Runner user
useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

# Install and run as a service
gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
gitlab-runner start

gitlab-runner register --url https://gitlab.linghai.me/ --registration-token a1RcMXHnsbASPk6X4iwZ

rm -f get-pip.py
rm cuda-keyring_1.0-1_all.deb 
reboot
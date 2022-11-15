#!/bin/bash
set -e

export BAZEL_VERSION=3.6.0
export ANDROID_NDK_VERSION=r21e

echo "Trying to create symbolic link ..."
if ! ln -s / /vagrant/link; then
	echo "You have to run 'vagrant up' with admin rights!"
	exit 1
fi
rm /vagrant/link

echo "Installing dependencies ..."
sudo add-apt-repository ppa:longsleep/golang-backports > /dev/null 2>&1
sudo apt-get -qq -y update > /dev/null
sudo apt-get -qq -y install golang-go pkg-config zip g++ zlib1g-dev unzip python3 python3-setuptools moreutils > /dev/null
sudo ln -sf /usr/bin/python3 /usr/bin/python

echo "Installing Android NDK ..."
cd /home/vagrant
wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
rm android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
mv android-ndk-${ANDROID_NDK_VERSION} android-ndk

echo "Setting up Go workspace ..."
echo 'export GOPATH="$HOME/go"' >> ~/.profile
echo 'export PATH="$HOME/.local/bin:$GOPATH/bin:$PATH"' >> ~/.profile
source ~/.profile
mkdir -p "$GOPATH"

echo "Building scionlab fork ..." # for reproducibility, fix a specific commit instead of SCION_COMMIT=scionlab
SCION_NAME=scionlab SCION_REPOSITORY=https://github.com/netsec-ethz/scion SCION_COMMIT=v2021.10 /vagrant/build.sh

echo "Done."

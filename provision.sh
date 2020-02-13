#!/bin/bash
set -e

# use this to set the version of SCION to be built:
export SCION_REPOSITORY=https://github.com/scionproto/scion
export SCION_COMMIT=v0.4.0
export BAZEL_VERSION=2.1.0
export ANDROID_NDK_VERSION=r20

# install dependencies
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get -y update
sudo apt-get -y install golang-go pkg-config zip g++ zlib1g-dev unzip python3

# install Bazel
wget -q https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh
bash ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh --user
rm ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

# install Android NDK
cd /home/vagrant
wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
rm android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
mv android-ndk-${ANDROID_NDK_VERSION} android-ndk

# set up Go workspace
echo 'export GOPATH="$HOME/go"' >> ~/.profile
echo 'export PATH="$HOME/.local/bin:$GOPATH/bin:$PATH"' >> ~/.profile
source ~/.profile
mkdir -p "$GOPATH"

# clone SCION
cd /vagrant
rm -rf /vagrant/scion
git clone $SCION_REPOSITORY
cd scion
git checkout $SCION_COMMIT
mkdir -p "$GOPATH/src/github.com/scionproto"
cd "$GOPATH/src/github.com/scionproto"
ln -s /vagrant/scion scion
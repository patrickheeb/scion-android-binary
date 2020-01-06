#!/bin/bash

# use this to set the version of SCION to be built:
export SCION_REPOSITORY=https://github.com/netsec-ethz/scion
export SCION_COMMIT=3a2301a68b3f365d2c832b88d6640c9f34cd17df
# to build latest SCION, use (this may require further modifications to keep up with changes in SCION):
# export SCION_REPOSITORY=https://github.com/scionproto/scion
# export SCION_COMMIT=master

# install latest Go
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get -y update
sudo apt-get -y install golang-go

# install bazel v0.25.3 (newer versions fail due to https://github.com/bazelbuild/rules_go/issues/2089)
sudo apt-get -y install pkg-config zip g++ zlib1g-dev unzip python3
wget https://github.com/bazelbuild/bazel/releases/download/0.25.3/bazel-0.25.3-installer-linux-x86_64.sh
bash ./bazel-0.25.3-installer-linux-x86_64.sh --user
rm ./bazel-0.25.3-installer-linux-x86_64.sh

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
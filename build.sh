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
mkdir -p "$GOPATH/src/github.com/scionproto"
cd "$GOPATH/src/github.com/scionproto"
git clone https://github.com/netsec-ethz/scion
cd scion

# build SCION
yes | ./env/deps
make -C go/proto
bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_arm //:scion --workspace_status_command=./tools/bazel-build-env
mkdir -p /vagrant/bin-arm /vagrant/bin-arm64
tar -kxf bazel-bin/scion.tar -C /vagrant/bin-arm
bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_arm64 //:scion --workspace_status_command=./tools/bazel-build-env
tar -kxf bazel-bin/scion.tar -C /vagrant/bin-arm64
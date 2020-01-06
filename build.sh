#!/bin/bash
set -e
export MAIN_FILES="beacon_srv/main.go border/main.go cert_srv/main.go godispatcher/main.go tools/logdog/main.go path_srv/main.go tools/scion-custpk-load/main.go sciond/main.go tools/scion-pki/main.go tools/scmp/main.go tools/showpaths/paths.go sig/main.go"
export BAZEL_FILES="beacon_srv/BUILD.bazel border/BUILD.bazel cert_srv/BUILD.bazel godispatcher/BUILD.bazel tools/logdog/BUILD.bazel path_srv/BUILD.bazel tools/scion-custpk-load/BUILD.bazel sciond/BUILD.bazel tools/scion-pki/BUILD.bazel tools/scmp/BUILD.bazel tools/showpaths/BUILD.bazel sig/BUILD.bazel"
pushd "$GOPATH/src/github.com/scionproto/scion"

# add code for creating a single SCION executable (to allow sharing RAM, and to compensate for missing dynamic linking)
cp -R /vagrant/scion-android go

# export main function as AndroidMain in all binaries
for f in $MAIN_FILES; do
    grep -qxF 'func AndroidMain() { main() }' go/$f || echo 'func AndroidMain() { main() }' >> go/$f
done

# make every binary's library public so they can be used as dependencies
for f in $BAZEL_FILES; do
    sed -E -i.orig 's_"//visibility:private"_"//visibility:public"_' go/$f
done

# prepend binary name to every flag definition to avoid collisions
for f in `find go -name '*.go'`; do
    [ ! -f $f.orig ] && sed -E -i.orig 's/(flag\.[^"]+")([^"]*)"/\1'$(echo $(dirname $f) | tr '/' '_' | sed -e 's/go_//')'_\2"/' $f
done

# build SCION for Android (32-bit and 64-bit) and this computer's architecture (for debugging)
rm -rf /vagrant/bin
mkdir /vagrant/bin
rm -f bazel-bin/go/scion-android/*/scion-android
yes | ./env/deps
make -C go/proto
bazel build //go/scion-android --workspace_status_command=./tools/bazel-build-env
bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_arm //go/scion-android --workspace_status_command=./tools/bazel-build-env
bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_arm64 //go/scion-android --workspace_status_command=./tools/bazel-build-env
for dir in `ls bazel-bin/go/scion-android`; do
    cp bazel-bin/go/scion-android/$dir/scion-android /vagrant/bin/scion-android-$dir
done
popd
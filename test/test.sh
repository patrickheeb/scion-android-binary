#!/bin/bash
set -e

# start godispatcher
rm -f /tmp/dispatcher.log
touch /tmp/dispatcher.log
./libscion-android.so godispatcher -lib_env_config config/disp.toml &

# start sciond
rm -f /tmp/sciond.log
touch /tmp/sciond.log
DISPATCHER_SOCKET=/tmp/dispatcher.sock ./libscion-android.so sciond -lib_env_config config/sd.toml &

# show logs
tail -f /tmp/dispatcher.log -f /tmp/sciond.log
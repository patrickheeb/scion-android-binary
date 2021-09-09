#!/bin/bash
set -e

# start dispatcher
./libscion-scionlab.so dispatcher --config config/disp.toml &

# start sciond
DISPATCHER_SOCKET=/tmp/dispatcher.sock ./libscion-scionlab.so sciond --config config/sd.toml &

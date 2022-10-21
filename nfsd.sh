#!/bin/bash

trap "stop; exit 0;" SIGTERM SIGINT

stop() {
  /usr/sbin/exportfs -uav
  /usr/sbin/rpc.nfsd 0
  kill -TERM $(pidof rpc.nfsd) $(pidof rpc.mountd) $(pidof rpcbind) > /dev/null 2>&1
  echo "Terminated."
}

set -uo pipefail
IFS=$'\n\t'

echo "/etc/exports content:"
cat /etc/exports
echo ""

while [ -z "$(pidof rpc.mountd)" ]; do
    echo "Starting rpcbind..."
    /sbin/rpcbind -w
    /sbin/rpcinfo

    echo "Starting NFS in the background..."
    /usr/sbin/rpc.nfsd --debug 8 --no-nfs-version 3

    echo "Exporting File System..."
    if /usr/sbin/exportfs -rv; then
        /usr/sbin/exportfs
    else
        echo "Export validation failed, exiting..."
        exit 1
    fi

    echo "Starting Mountd in the background..."
    /usr/sbin/rpc.mountd --debug all --no-udp --no-nfs-version 3

    if [ -z "$(pidof rpc.mountd)" ]; then
        echo "Startup of NFS failed, retrying..."
        sleep 30
    fi
done

echo "Startup successful"

while true; do
    if [ -z "$(pidof rpc.mountd)" ]; then
        echo "NFS failed, exit"
        break
    fi

    sleep 2
done

exit 1

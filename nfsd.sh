#!/bin/bash

trap "stop; exit 0;" SIGTERM SIGINT

stop() {
  /usr/sbin/exportfs -uav
  /usr/sbin/rpc.nfsd 0
  kill -TERM $(pidof rpc.nfsd) $(pidof rpc.mountd) $(pidof rpcbind) > /dev/null 2>&1
  echo "Terminated."
}

mkdir -p /nfs

# absolute paths seperated by ';'
if [ -n "${CREATE_DIRECTORIES}" ]; then
    remaining_paths=${CREATE_DIRECTORIES}
    while [ -n "$remaining_paths" ] ; do
        path=${remaining_paths%%;*}
        [ "$remaining_paths" = "${remaining_paths/;/}" ] && remaining_paths= || remaining_paths=${remaining_paths#*;}
        echo "ensure directory \"$path\" exists"
        mkdir -p "$path"
        eval "chmod ${CREATE_DIRECTORIES_MODE:-0755} \"$path\""
    done
fi

# absolute paths seperated by ';'
if [ -n "${LINK_DIRECTORIES}" ]; then
    remaining_paths=${LINK_DIRECTORIES}
    while [ -n "$remaining_paths" ] ; do
        path=${remaining_paths%%;*}
        [ "$remaining_paths" = "${remaining_paths/;/}" ] && remaining_paths= || remaining_paths=${remaining_paths#*;}
        dest="/nfs/$(basename $path)"
        echo "ensure directory \"$dest\" exists"
        mkdir -p "$dest"
        echo "bind \"$path\" -> \"$dest\""
        mount --bind $path $dest
    done
fi

set -uo pipefail
IFS=$'\n\t'

echo "/etc/exports content:"
cat /etc/exports
echo ""

while true; do
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
    else
        echo "Startup successful"
        break
    fi
done


while true; do
    if [ -z "$(pidof rpc.mountd)" ]; then
        echo "NFS failed, exit"
        break
    fi

    sleep 2
done

exit 1

FROM alpine:latest

RUN apk add --no-cache --update nfs-utils bash iproute2 && \
    rm -rf /var/cache/apk /sbin/halt /sbin/poweroff /sbin/reboot

RUN mkdir -p /var/lib/nfs/rpc_pipefs /var/lib/nfs/v4recovery && \
    echo "rpc_pipefs /var/lib/nfs/rpc_pipefs rpc_pipefs defaults 0 0" >> /etc/fstab && \
    echo "nfsd /proc/fs/nfsd nfsd defaults 0 0" >> /etc/fstab

COPY nfsd.sh /usr/bin/nfsd.sh
RUN chmod +x /usr/bin/nfsd.sh

ENTRYPOINT ["/usr/bin/nfsd.sh"]

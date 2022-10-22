# NFS Server

NFS Server Container Image for NFS v4 over TCP on port 2049.

## Deployment Example

Using the `app-template` from [ bjw-s Helm charts](https://github.com/bjw-s/helm-charts) for the deployment:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: &app nfs
  namespace: storage
spec:
  interval: 15m
  chart:
    spec:
      chart: app-template
      version: 0.2.2
      interval: 1h
      sourceRef:
        kind: HelmRepository
        name: bjw-s-charts
        namespace: flux-system

  values:
    global:
      nameOverride: *app

    image:
      repository: ghcr.io/niki-on-github/nfs-server
      tag: dev

    service:
      main:
        ports:
          http:
            enabled: false
          nfs:
            enabled: true
            port: 2049
            protocol: TCP
        externalTrafficPolicy: Local
        type: LoadBalancer
        externalIPs:
          - ${SVC_NFS_IP}

    securityContext:
      capabilities:
        add: ["SYS_ADMIN", "SETPCAP"]
      privileged: true

    env:
      # NOTE: use ';' as path seperator
      CREATE_DIRECTORIES: "/data/temp"

    configmap:
      config:
        enabled: true
        data:
          exports: |
            /data ${CLUSTER_PODS_NETWORK_IP_POOL}(rw,fsid=0,async,no_subtree_check,no_auth_nlm,insecure,no_root_squash)

    persistence:
      data:
        enabled: true
        type: hostPath
        hostPath: "${NFS_HOST_PATH}"
        mountPath: /data
      exports:
        enabled: true
        type: configMap
        mountPath: /etc/exports
        name: nfs-config
        subPath: exports

    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/hostname
                  operator: In
                  values:
                    - "${NFS_SERVER_AFFINITY_HOSTNAME}"
```

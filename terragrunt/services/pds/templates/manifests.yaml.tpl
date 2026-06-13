---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pds-data
  namespace: ${namespace}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${storage_class}
  resources:
    requests:
      storage: ${data_storage_size}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pds
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: pds
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: pds
  template:
    metadata:
      labels:
        app.kubernetes.io/name: pds
    spec:
      containers:
        - name: pds
          image: ${pds_image}:${pds_image_tag}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3000
          envFrom:
            - secretRef:
                name: pds-env
          env:
            - name: PDS_HOSTNAME
              value: ${hostname}
            - name: PDS_PORT
              value: "3000"
            - name: PDS_DATA_DIRECTORY
              value: /pds
            - name: PDS_BLOBSTORE_DISK_LOCATION
              value: /pds/blocks
            - name: PDS_BLOB_UPLOAD_LIMIT
              value: "104857600"
            - name: PDS_SERVICE_HANDLE_DOMAINS
              value: ${handle_domains}
            # plc.directory is the only Bluesky-PBC-operated dependency left:
            # did:plc identities are registered there. Fully avoiding it means
            # did:web accounts, which the reference PDS barely supports.
            - name: PDS_DID_PLC_URL
              value: https://plc.directory
            - name: PDS_BSKY_APP_VIEW_URL
              value: https://api.bsky.app
            - name: PDS_BSKY_APP_VIEW_DID
              value: did:web:api.bsky.app
            - name: PDS_REPORT_SERVICE_URL
              value: https://mod.bsky.app
            - name: PDS_REPORT_SERVICE_DID
              value: did:plc:ar7c4by46qjdydhdevvrndac
            - name: PDS_CRAWLERS
              value: ${crawlers}
            - name: PDS_RATE_LIMITS_ENABLED
              value: "true"
            - name: PDS_INVITE_REQUIRED
              value: "true"
            - name: LOG_ENABLED
              value: "true"
          volumeMounts:
            - name: data
              mountPath: /pds
          readinessProbe:
            httpGet:
              path: /xrpc/_health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /xrpc/_health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 30
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: pds-data
---
apiVersion: v1
kind: Service
metadata:
  name: pds
  namespace: ${namespace}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: pds
  ports:
    - name: http
      port: 3000
      targetPort: 3000
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: pds
  namespace: ${namespace}
spec:
  parentRefs:
    - name: ${gateway_name}
      namespace: ${gateway_namespace}
      sectionName: https
  hostnames:
    - ${hostname}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: pds
          port: 3000
%{ if length(handle_hostnames) > 0 ~}
---
# Handle hosts (e.g. tibor.<domain>) must reach the PDS so it can serve
# /.well-known/atproto-did for handle verification. Routing the whole host
# is harmless — the PDS answers with its landing page elsewhere.
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: pds-handles
  namespace: ${namespace}
spec:
  parentRefs:
    - name: ${gateway_name}
      namespace: ${gateway_namespace}
      sectionName: https
  hostnames:
%{ for handle_hostname in handle_hostnames ~}
    - ${handle_hostname}
%{ endfor ~}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: pds
          port: 3000
%{ endif ~}

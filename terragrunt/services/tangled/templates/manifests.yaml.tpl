---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tangled-sshkeys
  namespace: ${namespace}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${storage_class}
  resources:
    requests:
      storage: ${sshkeys_storage_size}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tangled-repos
  namespace: ${namespace}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${storage_class}
  resources:
    requests:
      storage: ${repo_storage_size}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tangled-app
  namespace: ${namespace}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${storage_class}
  resources:
    requests:
      storage: ${app_storage_size}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tangled
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: tangled-knot
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: tangled-knot
  template:
    metadata:
      labels:
        app.kubernetes.io/name: tangled-knot
    spec:
      containers:
        - name: knot
          image: ${knot_image}:${knot_image_tag}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 5555
            - name: ssh
              containerPort: 22
          env:
            - name: KNOT_SERVER_HOSTNAME
              value: ${hostname}
            - name: KNOT_SERVER_OWNER
              value: ${owner_did}
            - name: APPVIEW_ENDPOINT
              value: ${appview_endpoint}
            - name: KNOT_REPO_SCAN_PATH
              value: /home/git/repositories
            - name: KNOT_SERVER_DB_PATH
              value: /app/knotserver.db
            - name: KNOT_SERVER_LISTEN_ADDR
              value: :5555
            - name: KNOT_SERVER_INTERNAL_LISTEN_ADDR
              value: localhost:5444
          volumeMounts:
            - name: sshkeys
              mountPath: /etc/ssh/keys
            - name: repos
              mountPath: /home/git/repositories
            - name: app
              mountPath: /app
          readinessProbe:
            tcpSocket:
              port: 5555
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: 5555
            initialDelaySeconds: 30
            periodSeconds: 30
        - name: did-web
          image: ${did_web_image}:${did_web_image_tag}
          imagePullPolicy: IfNotPresent
          ports:
            - name: did-http
              containerPort: 80
          volumeMounts:
            - name: did-doc
              mountPath: /usr/share/nginx/html/.well-known/did.json
              subPath: did.json
              readOnly: true
          readinessProbe:
            httpGet:
              path: /.well-known/did.json
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: sshkeys
          persistentVolumeClaim:
            claimName: tangled-sshkeys
        - name: repos
          persistentVolumeClaim:
            claimName: tangled-repos
        - name: app
          persistentVolumeClaim:
            claimName: tangled-app
        - name: did-doc
          configMap:
            name: tangled-did-web
---
apiVersion: v1
kind: Service
metadata:
  name: tangled-http
  namespace: ${namespace}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: tangled-knot
  ports:
    - name: http
      port: 5555
      targetPort: 5555
---
apiVersion: v1
kind: Service
metadata:
  name: tangled-ssh
  namespace: ${namespace}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: tangled-knot
  ports:
    - name: ssh
      port: 22
      targetPort: 22
---
apiVersion: v1
kind: Service
metadata:
  name: tangled-did
  namespace: ${namespace}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: tangled-knot
  ports:
    - name: did-http
      port: 80
      targetPort: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: tangled
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
        - name: tangled-http
          port: 5555
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: tangled-did
  namespace: ${namespace}
spec:
  parentRefs:
    - name: ${gateway_name}
      namespace: ${gateway_namespace}
      sectionName: https
  hostnames:
    - ${did_hostname}
  rules:
    - matches:
        - path:
            type: Exact
            value: /.well-known/did.json
      backendRefs:
        - name: tangled-did
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: tangled-ssh
  namespace: ${namespace}
spec:
  parentRefs:
    - name: ${gateway_name}
      namespace: ${gateway_namespace}
      sectionName: ssh
  rules:
    - backendRefs:
        - name: tangled-ssh
          port: 22

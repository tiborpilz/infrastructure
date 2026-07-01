apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: authentik-valkey
  labels:
    app.kubernetes.io/name: valkey
    app.kubernetes.io/instance: authentik
spec:
  replicas: 1
  serviceName: authentik-valkey
  selector:
    matchLabels:
      app.kubernetes.io/name: valkey
      app.kubernetes.io/instance: authentik
  template:
    metadata:
      labels:
        app.kubernetes.io/name: valkey
        app.kubernetes.io/instance: authentik
    spec:
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: valkey
          image: ${valkey_image}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop: ["ALL"]
            seccompProfile:
              type: RuntimeDefault
          args:
            - --requirepass
            - $(VALKEY_PASSWORD)
            - --save
            - ""
            - --appendonly
            - "no"
          env:
            - name: VALKEY_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: authentik-valkey
                  key: password
          ports:
            - name: valkey
              containerPort: 6379
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - valkey-cli -a "$VALKEY_PASSWORD" PING
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: valkey
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 256Mi
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          emptyDir: {}

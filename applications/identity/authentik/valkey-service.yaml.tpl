apiVersion: v1
kind: Service
metadata:
  name: authentik-valkey
  labels:
    app.kubernetes.io/name: valkey
    app.kubernetes.io/instance: authentik
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: valkey
    app.kubernetes.io/instance: authentik
  ports:
    - name: valkey
      port: 6379
      targetPort: valkey

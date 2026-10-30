# Crear un pod de prueba dentro de K3s
kubectl run test-pod --image=alpine -it --rm --restart=Never -- sh

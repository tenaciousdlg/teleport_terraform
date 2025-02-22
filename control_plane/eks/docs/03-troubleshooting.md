1. Terraform Authentication Error

Error: `Error: Error creating EKS cluster: AccessDenied`
Solution: Ensure your AWS credentials have the required permissions for EKS:

```
aws sts get-caller-identity
```

2. Kubectl Connection Failure

Error: `Unable to connect to the server: dial tcp: no route to host`
Solution: Ensure your kubeconfig is updated and the cluster is reachable:

```
aws eks update-kubeconfig --region us-west-2 --name teleport-control-plane
```

3. Teleport Pod CrashLoopBackOff

Error: `kubectl get pods -n teleport` shows `CrashLoopBackOff`
Solution: Check the logs of the failing pod:

```
kubectl logs <pod-name> -n teleport
```

# Traefik Load Balancer

Traefik ingress controller configuration for Kubernetes clusters. Includes MetalLB load balancer and basic routing setup.

## Requirements

- Kubernetes cluster with MetalLB installed  
- kubectl access to the cluster
- Available IP address for load balancer service

**Note:** RBAC permissions are required for Traefik to access Kubernetes API resources.

## Configuration

Edit the following files to match your environment:

### Network Configuration
- `traefik.yaml`: Set `loadBalancerIP` to your desired IP address
- `metallb.yaml`: Set IP address range to match your load balancer IP

### Hostnames  
- `ingressroutes.yaml`: Update hostnames for dashboard and test application

## Deployment

```bash
./deploy.sh
```

Check deployment status:
```bash
kubectl --kubeconfig="../kubectl-configs/kubectl.yaml" get pods -n traefik
```

## Cleanup

```bash
./cleanup.sh
```

## Files

| File | Purpose |
|------|---------|
| `traefik.yaml` | Traefik deployment and service |
| `rbac.yaml` | Service account and permissions |
| `metallb.yaml` | Load balancer IP configuration |
| `whoami.yaml` | Test application |
| `ingressroutes.yaml` | Routing rules |
| `deploy.sh` | Deployment automation |
| `cleanup.sh` | Resource cleanup |

## Access

After successful deployment:

- Dashboard: `http://dashboard.k8s.brichet.be` 
- Test app: `http://whoami.k8s.brichet.be`

Configure DNS or `/etc/hosts`:
```
192.168.25.105 dashboard.k8s.brichet.be whoami.k8s.brichet.be
```

## Prerequisites

This configuration works with the cluster created by other scripts in this repository:

1. `../1-PreRequisites.sh` - Install required tools
2. `../2-PrepareProxmox.sh` - Prepare Proxmox environment  
3. `../3-DeployCluster.sh` - Deploy Talos Kubernetes cluster
4. `../4-GetSecrets.sh` - Retrieve cluster credentials

## Prerequisites

1. Run the cluster deployment scripts first:
   - `../1-PreRequisites.sh`
   - `../2-PrepareProxmox.sh` 
   - `../3-DeployCluster.sh`
   - `../4-GetSecrets.sh`

2. Ensure MetalLB is installed in your cluster for LoadBalancer service support.
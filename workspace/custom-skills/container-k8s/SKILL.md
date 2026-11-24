---
skill: container-k8s
title: "Container / Kubernetes"
category: "Security · Cloud/Infra"
load_when: "Containers/K8s; exposed kubelet/dashboard/etcd or SSRF into cluster."
pack: SUPERAGENT V10
bughunt: true
---
# Container / Kubernetes

## Where it pays
Cluster compromise = all workloads + secrets.

## Signals
kube-apiserver anon, kubelet :10250, dashboard, etcd :2379, docker :2375.

## Methodology
1. Exposed components (anon auth, /pods, /exec).
2. Metadata via SSRF from a pod.
3. RBAC gaps: over-permissive SA token.
4. Escape signals (privileged, docker socket, hostPath); registry exposure.

## Validation gate
List/read something anon/low-priv shouldn't reach — read-only, no disruption.

## Impact & chains
cluster takeover, secret theft, lateral movement.

**→ next: `../web/ssrf.md`.**

# Drills (the tasks that come back again and again)

Do each drill from a blank terminal. Only kubernetes.io open. Time it.
Paths are kubeadm defaults. Check every flag against kubernetes.io for v1.37 before you rely on it.

## D1. Safe static pod edit (use for every apiserver change)

```bash
ssh <node>; sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # outside manifests/
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# wait. Do not edit again until the pod is back.
watch crictl ps            # kube-apiserver comes back?
crictl ps -a | grep apiserver; crictl logs <id>
journalctl -u kubelet -f | grep -i apiserver
ls /var/log/pods/ | grep apiserver     # logs of a crashed container
```
Rule: every new file the apiserver reads needs a **hostPath volume + volumeMount**.

## D2. Audit logging

```yaml
# /etc/kubernetes/audit/policy.yaml   (first matching rule wins: specific rules first)
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
- level: RequestResponse
  resources: [{group: "", resources: ["secrets"]}]
  namespaces: ["prod"]
- level: Metadata
  resources: [{group: "", resources: ["secrets", "configmaps"]}]
- level: None
  users: ["system:kube-proxy"]
- level: Metadata
```
Flags: `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log`, `--audit-log-maxage=`, `--audit-log-maxbackup=`, `--audit-log-maxsize=`.
Mount `/etc/kubernetes/audit` (readOnly) and `/var/log/kubernetes/audit` (DirectoryOrCreate). Doc: kubernetes.io "Auditing".

## D3. Encryption at rest

```yaml
# /etc/kubernetes/enc/enc.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: ["secrets"]
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <head -c 32 /dev/urandom | base64>
  - identity: {}
```
Flag `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml` + mount. Then re-write all secrets:
`k get secrets -A -o json | k replace -f -`
Check in etcd:
```bash
ETCDCTL_API=3 etcdctl --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/apiserver-etcd-client.crt --key /etc/kubernetes/pki/apiserver-etcd-client.key \
  get /registry/secrets/<ns>/<name> | hexdump -C | head   # expect k8s:enc:aescbc:v1:key1
```

## D4. ImagePolicyWebhook and apiserver flags

```yaml
# /etc/kubernetes/admission/admission-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission/kubeconf   # check: clusters[].cluster.server is set
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
```
Flags: `--enable-admission-plugins=NodeRestriction,ImagePolicyWebhook`, `--admission-control-config-file=...` + mount.
Other common flags: `--anonymous-auth=false` (careful with probes), `--authorization-mode=Node,RBAC`, remove `--insecure-port` / `AlwaysAdmit`, `--profiling=false`.

## D5. AppArmor

```bash
ssh <node where pod runs>; sudo -i
apparmor_parser -q /path/profile   # load
aa-status | grep <profile-name>
```
```yaml
spec:
  containers:
  - name: c
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: <profile-name>   # the name inside the file, not the file name
```
Pin the pod to the node (`nodeName` or nodeSelector) if the profile is only on one node.

## D6. seccomp

Profile files go in `/var/lib/kubelet/seccomp/`. `localhostProfile` is relative to that folder.
```yaml
securityContext:
  seccompProfile:
    type: Localhost            # or RuntimeDefault
    localhostProfile: profiles/audit.json
```

## D7. kube-bench, kubelet, binaries

```bash
kube-bench run --targets master    # or node, etcd. Or run as a Job.
kube-bench run --targets master --check 1.2.20
# kubelet: /var/lib/kubelet/config.yaml
#   authentication.anonymous.enabled: false
#   authorization.mode: Webhook
#   readOnlyPort: 0
systemctl daemon-reload; systemctl restart kubelet
# binary check
sha512sum $(which kubelet); compare with https://dl.k8s.io/v1.37.x/bin/linux/amd64/kubelet.sha512
```

## D8. NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: app}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  egress:
  - ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]   # keep DNS
---
# block metadata, allow the rest
  egress:
  - to:
    - ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}
```
Remember: `namespaceSelector` and `podSelector` in **one** `from` item = AND. Two items = OR. Label `kubernetes.io/metadata.name` exists on every namespace.

Ingress TLS: `k create secret tls t --cert=c.crt --key=c.key`, then `spec.tls: [{hosts: [x], secretName: t}]`.

## D9. RBAC and ServiceAccounts

```bash
k create sa app -n ns
k create role r -n ns --verb=get,list --resource=pods
k create rolebinding rb -n ns --role=r --serviceaccount=ns:app
k auth can-i list pods -n ns --as=system:serviceaccount:ns:app
```
`automountServiceAccountToken: false` on the SA or in the pod spec.

## D10. Pod Security Admission and securityContext

```bash
k label ns team pod-security.kubernetes.io/enforce=restricted   # or baseline
k label ns team pod-security.kubernetes.io/warn=restricted
```
Restricted pod needs: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile.type: RuntimeDefault`.
Immutable: `readOnlyRootFilesystem: true` + `emptyDir` for paths the app writes. PSA checks new pods only: delete and recreate the old ones.

## D11. RuntimeClass (gVisor)

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata: {name: gvisor}
handler: runsc
---
spec:
  runtimeClassName: gvisor
```
Check: `k exec pod -- dmesg` shows gVisor.

## D12. Supply chain

```bash
trivy image --severity HIGH,CRITICAL nginx:1.19
trivy image -q --severity CRITICAL --format json <img>
trivy image --format cyclonedx -o sbom.json <img>     # or spdx-json
trivy sbom sbom.json                                  # scan an SBOM
bom generate --image <img> --format json -o sbom.spdx.json   # check bom docs (allowed)
kubesec scan pod.yaml
kube-linter lint pod.yaml
k get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
```
Dockerfile fixes: pin the tag, no root user (`USER 65534`), fewer layers, no secrets in ENV, small base image.

## D13. Falco and investigation

```bash
ls /etc/falco/   # falco.yaml, falco_rules.yaml, falco_rules.local.yaml (edit local / rules.d)
journalctl -u falco* -f      # or the falco pod logs
# change output: copy the rule to the local file, edit "output:", restart falco
crictl ps | grep <id>; crictl inspect <id> | grep -i pid
cat /proc/<pid>/cmdline; ls -l /proc/<pid>/exe
```
Output fields: `%evt.time %user.name %proc.name %container.id %k8s.pod.name`. Doc: falco.org (allowed).

## D14. Upgrade and host footprint

```bash
apt-mark unhold kubeadm && apt install kubeadm=1.37.x-* && apt-mark hold kubeadm
kubeadm upgrade plan; kubeadm upgrade apply v1.37.x     # worker: kubeadm upgrade node
k drain <node> --ignore-daemonsets; apt install kubelet=... kubectl=...; systemctl restart kubelet; k uncordon <node>
ss -tlpn; systemctl list-units --type=service --state=running
systemctl disable --now <svc>; apt remove <pkg>
```

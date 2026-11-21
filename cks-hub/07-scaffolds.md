# 07 Scaffolds: never type YAML from scratch (CKS, Kubernetes v1.37)

Checked 2026-11-21. I fetched every page below on that day. The docs site shows v1.37 as the current version.
Status in each block: **OK** = I saw the heading, file name and text on the page. **NOT VERIFIED** = no allowed page has it, or I did not see it.

Rule for each task: 1) generator if one exists, 2) else copy the example block from the allowed page, 3) then change it, 4) dry-run on the server, 5) apply.
Tip: on kubernetes.io, the copy icon at the top right of an example block copies only the YAML. The file name above the block (for example `service/networking/networkpolicy.yaml`) is not in the copy.

Order: domains in order of how often they come up in candidate reports (my estimate), topics in each domain in the same order.

---

## 0. Workflow first

### 0.1 Generators you can trust (flags checked on the kubectl reference pages)

```bash
export do="--dry-run=client -o yaml"          # then: kubectl run x --image=nginx $do > x.yaml
kubectl run web --image=nginx $do > pod.yaml   # Pod base for securityContext, AppArmor, seccomp, RuntimeClass, emptyDir
kubectl create deploy web --image=nginx $do > deploy.yaml
kubectl create sa app-sa -n team $do
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n team $do
kubectl create rolebinding rb --role=pod-reader --serviceaccount=team:app-sa -n team $do
kubectl create clusterrole secret-reader --verb=get,list --resource=secrets $do
kubectl create clusterrolebinding crb --clusterrole=secret-reader --user=jane --group=ops $do
kubectl create token app-sa -n team --duration 10m
kubectl create secret generic db --from-literal=user=admin --from-literal=pass=s3cr3t -n team $do
kubectl create secret tls app-tls --cert=tls.crt --key=tls.key -n team $do
kubectl create ingress secure --class=nginx --rule="app.example.com/*=web:80,tls=app-tls" -n team $do
kubectl set serviceaccount deployment web app-sa -n team
kubectl label ns team pod-security.kubernetes.io/enforce=restricted --overwrite
```

There is **no** `kubectl create networkpolicy`. The full list of `kubectl create` subcommands in v1.37: clusterrole, clusterrolebinding, configmap, cronjob, deployment, ingress, job, namespace, poddisruptionbudget, priorityclass, quota, role, rolebinding, secret, service, serviceaccount, token. Everything else is a copy from the docs.

### 0.2 Verify before apply

```bash
kubectl apply -f x.yaml --dry-run=server        # API server checks schema, admission, PSA. Catches typos in field names.
kubectl explain pod.spec.containers.securityContext            # exact field names
kubectl explain pod.spec --recursive | less                    # whole tree; search with /
kubectl explain networkpolicy.spec.egress.to --recursive
kubectl diff -f x.yaml                                          # what changes on a live object
kubectl auth can-i list secrets --as=system:serviceaccount:team:app-sa -n team   # RBAC check
```
For static pod manifests (no API server check): copy first, `cp kube-apiserver.yaml /root/kube-apiserver.yaml.bak` (keep the backup OUT of /etc/kubernetes/manifests), then edit, then watch `crictl ps -a | grep apiserver` and `crictl logs <id>` or `/var/log/pods/kube-system_kube-apiserver-*`.

### 0.3 How to paste safely in vim

- Before you paste: `:set paste`, then `i`, paste, `Esc`, `:set nopaste`. Or open with `vim -c 'set paste' x.yaml`. Without paste mode, autoindent shifts each line further right.
- Put this in ~/.vimrc at exam start: `set ts=2 sw=2 et ai` (spaces, not tabs).
- Show tabs and line ends: `:set list`. Move a block: select with `V`, then `>` or `<`.
- Check the indentation after the paste: `yq . x.yaml` (if yq exists; NOT VERIFIED that the exam host has yq) or `kubectl apply -f x.yaml --dry-run=server`. A parse error names the line.
- Other option, no editor: `cat <<'EOF' > x.yaml` then paste, then `EOF`. Quote the 'EOF' so the shell does not expand $ signs.

---

## 1. Cluster Setup (15%)

### 1.1 NetworkPolicy: default deny ingress / egress / all  (OK)
| | |
|---|---|
| Search | `network policies` |
| URL | https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-policies |
| Copy | "Default deny all ingress traffic" `service/networking/network-policy-default-deny-ingress.yaml` / "Default deny all egress traffic" `network-policy-default-deny-egress.yaml` / "Default deny all ingress and all egress traffic" `network-policy-default-deny-all.yaml` |
| Generator | none |
| Change | add `metadata.namespace`. Keep `podSelector: {}`. |
| Trap | A policy applies only in its own namespace. Deny egress also blocks DNS, so add 1.2 if pods must resolve names. |

**Manifest** `service/networking/network-policy-default-deny-ingress.yaml` (kubernetes.io example)
```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Manifest** `service/networking/network-policy-default-deny-egress.yaml` (kubernetes.io example)
```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

**Manifest** `service/networking/network-policy-default-deny-all.yaml` (kubernetes.io example)
```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 1.2 NetworkPolicy: allow DNS egress  (page has no DNS example; built from OK parts)
| | |
|---|---|
| URL | same page, "The NetworkPolicy resource", `service/networking/networkpolicy.yaml` (copy the egress block) |
| Change | delete the ingress part and the ipBlock; set ports to 53 UDP and 53 TCP. Result: |
```yaml
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```
Trap: an egress rule with only `ports` (no `to`) allows port 53 to any address. That is often what the task wants. Read the task.

**Manifest** `service/networking/networkpolicy.yaml` (kubernetes.io example)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```

### 1.3 NetworkPolicy: ipBlock with except 169.254.169.254 (metadata)  (OK)
| | |
|---|---|
| URL | same page, `service/networking/networkpolicy.yaml` |
| Copy | the `ipBlock: cidr / except` lines (in the ingress part; move them under egress `to:`) |
| Change | `cidr: 0.0.0.0/0`, `except: [169.254.169.254/32]`, `policyTypes: [Egress]` |
| Trap | `/32` is required. ipBlock is for cluster-external IPs; pod IPs are not reliable there. |

**Manifest** `service/networking/networkpolicy.yaml` (kubernetes.io example)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```

### 1.4 NetworkPolicy: namespaceSelector  (OK)
| | |
|---|---|
| URL | same page, "Behavior of to and from selectors", "Targeting multiple namespaces by label", "Targeting a Namespace by its name" |
| Copy | the YAML fragment under "namespaceSelector and podSelector" |
| Change | select a namespace by name with the fixed label `kubernetes.io/metadata.name: <ns>` |
| Trap | One dash with both selectors = AND (pods with label X in namespace Y). Two dashes = OR. Check with `kubectl describe netpol`. |

**Manifest** `service/networking/networkpolicy.yaml` (kubernetes.io example)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```

### 1.5 CiliumNetworkPolicy  (OK, Cilium 1.20.5 docs)
| | |
|---|---|
| URL | https://docs.cilium.io/en/stable/security/policy/layer3/ (L3) and https://docs.cilium.io/en/stable/security/policy/layer4/ (L4) |
| Copy | "Simple Ingress Allow" (name l3-rule), "Simple Egress Deny" (egressDeny), "Ingress/Egress Default Deny" (deny-all-egress, `egress: - {}`), "Allow to external CIDR block" (toCIDR, toCIDRSet with except), "Example (L4)" (toPorts, port as a string "80") |
| Generator | none |
| Change | `apiVersion: cilium.io/v2`, kind CiliumNetworkPolicy, `endpointSelector` (not podSelector), add namespace |
| Trap | Note: the old URL /security/policy/language/ now redirects. `fromRequires/toRequires` are removed in 1.19. Deny rules (ingressDeny/egressDeny) win over allow rules. |

### 1.6 Ingress with TLS  (OK)
| | |
|---|---|
| Search | `ingress tls` |
| URL | https://kubernetes.io/docs/concepts/services-networking/ingress/#tls |
| Copy | "TLS", `service/networking/tls-example-ingress.yaml`, plus the TLS Secret example `secret/tls-auth-secret.yaml` on the Secret page if you need YAML |
| Generator | `kubectl create secret tls app-tls --cert=tls.crt --key=tls.key` then `kubectl create ingress secure --class=nginx --rule="app.example.com/*=web:80,tls=app-tls" --dry-run=client -o yaml` |
| Change | host, secretName, service name/port, ingressClassName |
| Trap | Path without a trailing `*` gives pathType Exact. Secret must be in the Ingress namespace. HTTPS redirect: ingress-nginx annotation `nginx.ingress.kubernetes.io/ssl-redirect` (or force-ssl-redirect), on https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/ (OK). |

**Manifest** `service/networking/tls-example-ingress.yaml` (kubernetes.io example)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-example-ingress
spec:
  tls:
  - hosts:
      - https-example.foo.com
    secretName: testsecret-tls
  rules:
  - host: https-example.foo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service1
            port:
              number: 80
```

### 1.7 kubelet config hardening  (OK)
| | |
|---|---|
| Search | `kubelet authentication authorization` |
| URL | https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/ (flags) and https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletAuthentication (fields) |
| Copy | nothing to copy as a block; edit `/var/lib/kubelet/config.yaml` (kubeadm path) |
| Change | `authentication.anonymous.enabled: false`, `authentication.webhook.enabled: true`, `authorization.mode: Webhook`. Then `systemctl daemon-reload; systemctl restart kubelet`. |
| Trap | Default kubelet authorization is AlwaysAllow. A command-line flag in the systemd drop-in wins over the config file, so check `ps aux \| grep kubelet` too. Do it on every node the task names. |

### 1.8 Verify binary sha512  (partly OK)
| | |
|---|---|
| URL | https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux |
| Copy | the page shows the sha256 pattern only: `echo "$(cat kubectl.sha256)  kubectl" \| sha256sum --check` |
| Change | use sha512: `sha512sum kubelet` and compare, or `echo "<hash>  /usr/bin/kubelet" \| sha512sum --check` |
| Trap | Two spaces between hash and file name. `https://dl.k8s.io/release/v1.37.0/bin/linux/amd64/kubectl.sha512` exists (HTTP 200, checked), but the docs page does not mention sha512. Compare the version too (`kubelet --version`). |

---

### 1.9 kube-bench: run, read, fix  (NOT VERIFIED: no allowed docs, commands from memory)
| | |
|---|---|
| Run | `kube-bench run --targets master` (control plane) or `--targets node` (worker). One check: `kube-bench run --targets master --check 1.2.21` |
| Read | Each FAIL has a "Remediation" text at the end of the output. It names the file and the exact flag or field. |
| Fix | apiserver, controller-manager, scheduler, etcd: edit the static pod in `/etc/kubernetes/manifests/` (see 4.3). kubelet: edit `/var/lib/kubelet/config.yaml` (see 1.7), then `systemctl restart kubelet`. |
| Check | Run the same check again. It must show PASS. |
| Trap | Finding the FAIL gives no points. Apply the fix and check it again. Back up a manifest outside `manifests/` before you edit it. |

## 2. Minimize Microservice Vulnerabilities (20%)

### 2.1 Pod Security Admission namespace labels  (OK)
| | |
|---|---|
| Search | `enforce pod security standards namespace labels` |
| URL | https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/ and https://kubernetes.io/docs/concepts/security/pod-security-admission/ |
| Copy | "Requiring the baseline Pod Security Standard with namespace labels" (Namespace YAML with enforce/audit/warn and -version v1.37) |
| Generator | `kubectl label ns team pod-security.kubernetes.io/enforce=restricted --overwrite` ; test first with `kubectl label --dry-run=server --overwrite ns team pod-security.kubernetes.io/enforce=restricted` |
| Trap | Modes: enforce, audit, warn. Levels: privileged, baseline, restricted. Enforce does not touch running pods; delete and recreate them. For Deployments, warn shows at create time, but enforce blocks only the Pods (check ReplicaSet events). |

### 2.2 securityContext (runAsNonRoot, readOnlyRootFilesystem, capabilities drop, allowPrivilegeEscalation, seccompProfile RuntimeDefault)  (OK)
| | |
|---|---|
| Search | `security context` |
| URL | https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| Copy | "Set the security context for a Pod" `pods/security/security-context.yaml` (has runAsUser, fsGroup, emptyDir, allowPrivilegeEscalation: false). "Set capabilities for a Container" `pods/security/security-context-4.yaml`. "Set the Seccomp Profile for a Container" (RuntimeDefault fragment). |
| Generator | `kubectl run web --image=nginx --dry-run=client -o yaml`, then add the fields |
| Change | container level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `capabilities: {drop: ["ALL"]}`, `seccompProfile: {type: RuntimeDefault}` |
| Trap | No docs example shows runAsNonRoot or readOnlyRootFilesystem in YAML. Get exact names with `kubectl explain pod.spec.containers.securityContext`. Restricted list: https://kubernetes.io/docs/concepts/security/pod-security-standards/ . runAsNonRoot with an image that runs as root fails at start (CreateContainerConfigError); add runAsUser. |

**Manifest** `pods/security/security-context.yaml` (kubernetes.io example)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    supplementalGroups: [4000]
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  containers:
  - name: sec-ctx-demo
    image: busybox:1.28
    command: [ "sh", "-c", "sleep 1h" ]
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:
      allowPrivilegeEscalation: false
```

**Manifest** `pods/security/security-context-4.yaml` (kubernetes.io example)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo-4
spec:
  containers:
  - name: sec-ctx-4
    image: gcr.io/google-samples/hello-app:2.0
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "SYS_TIME"]
```

### 2.3 Secrets: create, mount as volume, as env  (OK)
| | |
|---|---|
| Search | `distribute credentials secure` |
| URL | https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/ |
| Copy | volume: "Create a Pod that has access to the secret data through a Volume" `pods/inject/secret-pod.yaml`. one env: "Define a container environment variable with data from a single Secret" `pods/inject/pod-single-secret-env-variable.yaml`. all keys: "Configure all key-value pairs in a Secret as container environment variables" (envFrom) |
| Generator | `kubectl create secret generic db --from-literal=user=admin` |
| Change | secretName, mountPath, key names |
| Trap | Decode: `kubectl get secret db -o jsonpath='{.data.user}' \| base64 -d`. Mount with readOnly: true. A Secret is only base64, not encrypted (see 2.4). |

### 2.4 EncryptionConfiguration (aescbc / secretbox + identity)  (OK)
| | |
|---|---|
| Search | `encrypt data at rest` |
| URL | https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file |
| Copy | "Write an encryption configuration file" (aescbc key1 + `identity: {}`) and the static pod fragment in "Use the new encryption configuration file" |
| Generator | key: `head -c 32 /dev/urandom \| base64` |
| Change | resources: [secrets]; provider aescbc or secretbox first, `identity: {}` last. Save to /etc/kubernetes/enc/enc.yaml. Flag `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml` plus volume "enc" (hostPath /etc/kubernetes/enc, DirectoryOrCreate) and volumeMount (readOnly). |
| Trap | The FIRST provider encrypts new writes. identity first = no encryption. Old Secrets stay plain until `kubectl get secrets -A -o json \| kubectl replace -f -`. |

### 2.5 etcdctl: read a Secret from etcd  (OK)
| | |
|---|---|
| URL | https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted ; also https://etcd.io/docs/v3.6/dev-guide/interacting_v3/#read-keys |
| Copy | `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C` |
| Change | namespace and name in the key path |
| Trap | Encrypted data starts with `k8s:enc:aescbc:v1:key1`. Take cert paths from /etc/kubernetes/manifests/etcd.yaml. Add `--endpoints=https://127.0.0.1:2379` if etcd is not local. |

### 2.6 RuntimeClass (gVisor runsc)  (OK)
| | |
|---|---|
| Search | `runtime class` |
| URL | https://kubernetes.io/docs/concepts/containers/runtime-class/#2-create-the-corresponding-runtimeclass-resources |
| Copy | RuntimeClass block (`apiVersion: node.k8s.io/v1`, name myclass, handler myconfiguration) and the Pod under "Usage" |
| Generator | Pod: `kubectl run` then add `spec.runtimeClassName` |
| Change | `name: gvisor`, `handler: runsc` |
| Trap | RuntimeClass is cluster-scoped (no namespace). handler must match the runtime name in /etc/containerd/config.toml (`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.${HANDLER_NAME}]`). gVisor docs are not allowed. Check: `kubectl exec pod -- dmesg` shows gVisor lines (NOT VERIFIED on an allowed page). |

### 2.7 Istio PeerAuthentication STRICT  (OK)
| | |
|---|---|
| URL | https://istio.io/latest/docs/reference/config/security/peer_authentication/ and https://istio.io/latest/docs/tasks/security/authentication/authn-policy/#globally-enabling-istio-mutual-tls-in-strict-mode |
| Copy | first example "Policy to require mTLS traffic for all workloads under namespace foo" |
| Change | `apiVersion: security.istio.io/v1`, namespace. Mesh wide: namespace istio-system (root namespace), no selector. |
| Trap | Pods need the sidecar (label ns `istio-injection=enabled`, then restart pods; NOT VERIFIED on the pages I read). A workload selector in the root namespace is ignored. |

### 2.8 Cilium encryption (WireGuard) check  (OK)
| | |
|---|---|
| URL | https://docs.cilium.io/en/stable/security/network/encryption-wireguard/#validate-the-setup |
| Copy | `kubectl -n kube-system exec -ti ds/cilium -- cilium-dbg status \| grep Encryption` (expect "Wireguard [cilium_wg0 ... Peers: N-1]") |
| Change | enable: Helm `--set encryption.enabled=true --set encryption.type=wireguard` or ConfigMap `enable-wireguard: true` then restart cilium agents |
| Trap | The binary in the pod is `cilium-dbg` in current versions. Peers = nodes minus one. |

---

## 3. Monitoring, Logging and Runtime Security (20%)

### 3.1 Audit Policy + apiserver flags + mounts  (OK)
| | |
|---|---|
| Search | `auditing` |
| URL | https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy and #log-backend |
| Copy | "Audit policy" `audit/audit-policy.yaml`; "Log backend" flags and the volumeMounts / volumes block |
| Change | delete the rules you do not need, keep the order the task gives. Flags: `--audit-policy-file=/etc/kubernetes/audit-policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log`, `--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`. Mounts: policy hostPath type File (readOnly), log dir type DirectoryOrCreate. |
| Trap | The first matching rule wins, so put specific rules first and the catch-all last. Secrets at Metadata level only (no RequestResponse). Wrong path or mount = apiserver does not start. |

**Manifest** `audit/audit-policy.yaml` (kubernetes.io example)
```yaml
apiVersion: audit.k8s.io/v1 # This is required.
kind: Policy
# Don't generate audit events for all requests in RequestReceived stage.
omitStages:
  - "RequestReceived"
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      # Resource "pods" doesn't match requests to any subresource of pods,
      # which is consistent with the RBAC policy.
      resources: ["pods"]
  # Log "pods/log", "pods/status" at Metadata level
  - level: Metadata
    resources:
    - group: ""
      resources: ["pods/log", "pods/status"]

  # Don't log requests to a configmap called "controller-leader"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
      resourceNames: ["controller-leader"]

  # Don't log watch requests by the "system:kube-proxy" on endpoints or services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: "" # core API group
      resources: ["endpoints", "services"]

  # Don't log authenticated requests to certain non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
    - "/api*" # Wildcard matching.
    - "/version"

  # Log the request body of configmap changes in kube-system.
  - level: Request
    resources:
    - group: "" # core API group
      resources: ["configmaps"]
    # This rule only applies to resources in the "kube-system" namespace.
    # The empty string "" can be used to select non-namespaced resources.
    namespaces: ["kube-system"]

  # Log configmap and secret changes in all other namespaces at the Metadata level.
  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets", "configmaps"]

  # Log all other resources in core and extensions at the Request level.
  - level: Request
    resources:
    - group: "" # core API group
    - group: "extensions" # Version of group should NOT be included.

  # A catch-all rule to log all other requests at the Metadata level.
  - level: Metadata
    # Long-running requests like watches that fall under this rule will not
    # generate an audit event in RequestReceived.
    omitStages:
      - "RequestReceived"
```

### 3.2 Falco custom rule / override output  (OK)
| | |
|---|---|
| URL | https://falco.org/docs/concepts/rules/basic-elements/#rules (rule shape) ; https://falco.org/docs/concepts/rules/overriding/#append-and-replace-items-in-a-rule ; https://falco.org/docs/concepts/outputs/formatting/#adding-an-override-to-a-specific-rule ; fields: https://falco.org/docs/reference/rules/supported-fields/ ; rule names: https://falco.org/docs/reference/rules/default-rules/ |
| Copy | override output: `- rule: <exact name>` / `output: ...` / `override:` / `  output: replace`. New rule: the shell_in_container example. |
| Change | put it in /etc/falco/falco_rules.local.yaml (or /etc/falco/rules.d/). Fields: `%evt.time %user.name %proc.name %proc.cmdline %container.id %container.name %k8s.pod.name %k8s.ns.name %fd.name` |
| Trap | Rule name must match exactly (for example "Terminal shell in container", "Read sensitive file untrusted", "Write below etc"). Do not edit falco_rules.yaml. Restart and read logs: `systemctl restart falco; journalctl -u falco -f` (NOT VERIFIED on falco.org). The `append: true` key is deprecated; use `override:`. |

### 3.3 Immutable container: readOnlyRootFilesystem + emptyDir  (OK)
| | |
|---|---|
| Search | `volume types emptydir` |
| URL | https://kubernetes.io/docs/reference/storage/volume-types/#emptydir-configuration-example (moved here from concepts/storage/volumes) |
| Copy | "emptyDir configuration example" (test-pd, /cache) or `pods/storage/redis.yaml` on https://kubernetes.io/docs/tasks/configure-pod-container/configure-volume-storage/ |
| Change | add `securityContext.readOnlyRootFilesystem: true`; one emptyDir per path the app writes (/tmp, /var/cache/nginx, /var/run) |
| Trap | nginx crashes without writable /var/cache/nginx and /var/run. Check `kubectl logs` for "Read-only file system". |

---

## 4. Cluster Hardening (15%)

### 4.1 RBAC Role / ClusterRole / bindings  (OK)
| | |
|---|---|
| Search | `rbac` |
| URL | https://kubernetes.io/docs/reference/access-authn-authz/rbac/#command-line-utilities |
| Copy | only if needed: `access/simple-role.yaml`, `access/simple-clusterrole.yaml`, `access/simple-rolebinding-with-role.yaml`, `access/simple-rolebinding-with-clusterrole.yaml`, `access/simple-clusterrolebinding.yaml` |
| Generator | see 0.1. Extras: `--resource-name=x`, `--resource=rs.apps`, `--resource=pods,pods/status`, `--non-resource-url=/logs/*` |
| Change | namespace, subjects |
| Trap | You cannot change roleRef of a binding; delete and recreate. SA subject format is `--serviceaccount=ns:name`. Least privilege: remove `*` verbs and the bind, escalate, impersonate verbs. Test with `kubectl auth can-i --as`. |

### 4.2 ServiceAccount + automountServiceAccountToken  (OK)
| | |
|---|---|
| Search | `configure service account` |
| URL | https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#opt-out-of-api-credential-automounting |
| Copy | SA block (build-robot, `automountServiceAccountToken: false`) and the Pod block. Projected token: `pods/pod-projected-svc-token.yaml` |
| Generator | `kubectl create sa app-sa $do`, `kubectl set serviceaccount deployment web app-sa`, `kubectl create token app-sa --duration 10m` |
| Change | add the field on SA or on Pod spec |
| Trap | Pod spec value wins over SA value. Field is at Pod spec level, not container. Do not use the default SA for apps. |

### 4.3 kube-apiserver static pod: hostPath volume / volumeMount pattern  (OK)
| | |
|---|---|
| URL | https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file and https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#log-backend |
| Copy | the "# add this line" fragment (flag + volumeMount + volume) |
| Change | name, path, type (File for one file, DirectoryOrCreate for a directory), readOnly |
| Trap | Same name in volumes and volumeMounts. Flag path must be the path INSIDE the container. One wrong space = no apiserver. Wait 30 to 60 s; check `crictl ps -a`. Flag reference: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/ |

### 4.4 kubeadm upgrade  (OK)
| | |
|---|---|
| Search | `upgrading kubeadm clusters` |
| URL | https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/ |
| Copy | step blocks: "Upgrading control plane nodes", "Call kubeadm upgrade", "Drain the node", "Upgrade kubelet and kubectl", "Uncordon the node", "Upgrade worker nodes" |
| Change | version: `apt-cache madison kubeadm`, then `apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.37.x-*' && apt-mark hold kubeadm`; `kubeadm upgrade plan`; `kubeadm upgrade apply v1.37.x` (first control plane) or `kubeadm upgrade node` (others, workers); drain; kubelet + kubectl; `systemctl daemon-reload; systemctl restart kubelet`; uncordon |
| Trap | Drain from a host with kubectl access, not from the worker. `--ignore-daemonsets`. The pkgs.k8s.io repo is per minor version; change /etc/apt/sources.list.d/kubernetes.list for a minor jump. |

---

### 4.5 PKI: keys, CSRs and certificates with openssl  (pages OK, commands from memory)
| | |
|---|---|
| Search | `certificates` and `certificate signing requests` |
| URL | https://kubernetes.io/docs/tasks/administer-cluster/certificates/#openssl and https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#normal-user |
| Copy | the openssl steps (genrsa, req, x509) from the first page. The "Create private key" and CSR steps from the second page. |
| Key | `openssl genrsa -out user.key 2048` (or 3072, 4096) |
| CSR | `openssl req -new -key user.key -out user.csr -subj "/CN=jane/O=dev/O=ops"`. SAN: add `-addext "subjectAltName=DNS:app.local,IP:10.0.0.5"` |
| CA | `openssl req -x509 -new -nodes -key ca.key -subj "/CN=my-ca" -days 365 -out ca.crt` |
| Sign | `openssl x509 -req -in user.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out user.crt -days 365` |
| Self-signed | `openssl req -x509 -newkey rsa:2048 -nodes -keyout tls.key -out tls.crt -days 365 -subj "/CN=app.local"` |
| Inspect | `openssl x509 -in c.crt -noout -text`. Short: `-noout -subject -issuer -dates`. Base64 cert: `base64 -d file > c.crt` first. Live server: `openssl s_client -connect host:443 </dev/null \| openssl x509 -noout -text` |
| Verify | `openssl verify -CAfile ca.crt user.crt` (must print OK) |
| Key match | `openssl x509 -noout -modulus -in c.crt \| openssl md5` and `openssl rsa -noout -modulus -in k.key \| openssl md5` must be the same |
| Trap | Write the output to the exact path from the task. `-subj` order matters for the grader: CN first, then O. |

## 5. Supply Chain Security (20%)

### 5.1 ImagePolicyWebhook: AdmissionConfiguration + kubeconfig  (OK)
| | |
|---|---|
| Search | `admission controllers imagepolicywebhook` |
| URL | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook (section "Configuration file format") |
| Copy | AdmissionConfiguration with embedded `configuration: imagePolicy:` (second block), and the kubeconfig block (clusters / users) |
| Change | `kubeConfigFile` absolute path, `defaultAllow: false` (fail closed), server URL https. Flags: `--enable-admission-plugins=NodeRestriction,ImagePolicyWebhook` and `--admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml`. hostPath mount of /etc/kubernetes/admission (pattern 4.3). |
| Trap | Add to the existing plugin list, do not replace it. The kubeconfig needs `contexts` and `current-context` if the task file lacks them (NOT VERIFIED: the doc block shows only clusters and users). Backend must use TLS. |

### 5.2 bom generate SBOM  (OK)
| | |
|---|---|
| URL | https://kubernetes-sigs.github.io/bom/cli-reference/bom_generate/ |
| Copy | flags list |
| Command | `bom generate --image registry.k8s.io/kube-apiserver:v1.37.0 --format json --output /root/sbom.json` ; directory: `bom generate -d . -o sbom.spdx` |
| Trap | Default format is tag-value (SPDX text). The task often wants json; read it. `-i` = image, `-o` = output file, `-d` = dirs, `--image-archive` = tarball. |

### 5.3 Kubesec / KubeLinter  (NOT VERIFIED: no allowed docs)
| | |
|---|---|
| Docs | None on the allowed list. kubernetes.io/blog/2018/07/18/11-ways-not-to-get-hacked/ only says "kubesec generates risk scores for resources" and shows a JSON score. |
| Use | `kubesec scan pod.yaml` ; `kube-linter lint pod.yaml` ; for both: `--help` first. Trivy (not allowed docs): `trivy image --severity HIGH,CRITICAL nginx:1.27`. |
| Trap | Commands from memory. Trust `--help` on the exam host over this line. |

---

## 6. System Hardening (10%)

### 6.1 AppArmor in pod spec (appArmorProfile field)  (OK)
| | |
|---|---|
| Search | `apparmor` |
| URL | https://kubernetes.io/docs/tutorials/security/apparmor/#example and #appArmorProfile |
| Copy | "Example" `pods/security/hello-apparmor.yaml` (Pod level). Container level: security-context page, "Set the AppArmor Profile for a Container". |
| Change | `appArmorProfile: {type: Localhost, localhostProfile: <profile name>}` |
| Trap | localhostProfile is the profile NAME inside the file, not the file path. Load on the node first: `apparmor_parser -q /path/profile`, check `aa-status \| grep <name>` (NOT VERIFIED on the page). Profile missing on the node = Pod does not start (page shows it stuck). Use the field, not the old annotation `container.apparmor.security.beta.kubernetes.io`. Verify: `kubectl exec pod -- cat /proc/1/attr/current`. |

**Manifest** `pods/security/hello-apparmor.yaml` (kubernetes.io example)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-apparmor-example-deny-write
  containers:
  - name: hello
    image: busybox:1.28
    command: [ "sh", "-c", "echo 'Hello AppArmor!' && sleep 1h" ]
```

### 6.2 seccomp Localhost profile  (OK)
| | |
|---|---|
| Search | `seccomp` |
| URL | https://kubernetes.io/docs/tutorials/security/seccomp/ ("Create a Pod with a seccomp profile for syscall auditing") |
| Copy | `pods/security/seccomp/ga/audit-pod.yaml` (Localhost) or `pods/security/seccomp/ga/default-pod.yaml` (RuntimeDefault) |
| Change | `localhostProfile: profiles/audit.json` is relative to /var/lib/kubelet/seccomp/ ; put the file at /var/lib/kubelet/seccomp/profiles/audit.json on the node |
| Trap | Path is relative, never absolute. File must be on every node the pod can run on. Wrong path = CreateContainerError. |

---

**Manifest** `pods/security/seccomp/ga/default-pod.yaml` (kubernetes.io example)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: default-pod
  labels:
    app: default-pod
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: test-container
    image: hashicorp/http-echo:1.0
    args:
    - "-text=just made some more syscalls!"
    securityContext:
      allowPrivilegeEscalation: false
```

**Manifest** `pods/security/seccomp/ga/audit-pod.yaml` (kubernetes.io example)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: audit-pod
  labels:
    app: audit-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/audit.json
  containers:
  - name: test-container
    image: hashicorp/http-echo:1.0
    args:
    - "-text=just made some syscalls!"
    securityContext:
      allowPrivilegeEscalation: false
```

**Manifest** `pods/security/seccomp/profiles/audit.json` (kubernetes.io example)
```json
{
    "defaultAction": "SCMP_ACT_LOG"
}
```

**Manifest** `pods/security/seccomp/profiles/violation.json` (kubernetes.io example)
```json
{
    "defaultAction": "SCMP_ACT_ERRNO"
}
```

## 7. What I could not verify

- DNS egress NetworkPolicy: no example on the page. Block in 1.2 is built from verified parts.
- runAsNonRoot and readOnlyRootFilesystem: no YAML example on any allowed page. Use kubectl explain.
- sha512: kubernetes.io shows only sha256. The .sha512 file on dl.k8s.io exists.
- Falco restart and log commands (systemctl, journalctl): not on the pages I read.
- gVisor check with dmesg: gVisor docs are not allowed.
- ImagePolicyWebhook kubeconfig contexts: the doc block shows only clusters and users.
- Kubesec, KubeLinter, Trivy: no allowed docs. yq on the exam host: unknown.
- kube-bench (1.9) and the openssl commands in 4.5: from memory. The two PKI doc pages are real.
- `aa-status` and the Istio `istio-injection=enabled` label: not on the pages I read.

# 02 Task review: cks-real-1, cks-real-2, cks-real-3

Checked 2026-11-21 against CKS curriculum v1.37 (github.com/cncf/curriculum, "CKS_Curriculum v1.37.pdf"), kubernetes.io and falco.org. Read only: nothing was run on the lab VM.

Line numbers refer to the current files. Paths are relative to `exams/`.

## How grading affects the review

`server/grading.go` counts one check per `echo "FAIL` in the script. `applyBaseline` then scores only the checks that FAILED right after setup. A check that PASSES after setup gets no weight, and if it fails later it is ignored.

Result: every "do not delete or change X" guard that passes after setup is never graded. Example: in trivy-critical, `kubectl -n scan delete pod --all` gets full points. Rule for all fixes below: put each guard into a check that fails after setup (for example the last positive check), so that breaking the guard costs points.

No script has a FAIL inside a loop. No FAIL message is printed without `exit 1`. No removed API is taught as the answer: AppArmor uses `securityContext.appArmorProfile` (annotations are only accepted as an alternative), audit uses `audit.k8s.io/v1`, PSA replaces PSP, `AuthenticationConfiguration` with `anonymous.conditions` is `apiserver.config.k8s.io/v1` and stable since v1.34. `aescbc` is still a documented provider. Falco still loads `/etc/falco/falco_rules.local.yaml` by default and the rule `Read sensitive file untrusted` still exists in the stable rule set. kube-bench maps v1.37 down to benchmark `cis-2.0` (target `master` still exists).

Identical scripts: 19 task slots are byte-for-byte copies of a task in another mock. A fix in one copy must be made in every copy (listed per task).

## Summary table

| Mock / task | Verdict | Reason |
|---|---|---|
| real-1/01-netpol-microseg | FIX | `podSelector: {}` of deny-all-ingress is not checked |
| real-1/02-cis-kube-bench-master | FIX | Only runs a tool and counts lines; no fix, no real CIS work |
| real-1/03-verify-binaries | FIX | "Keep the good binaries" guard is ignored by the baseline; `rm *` scores full |
| real-1/04-rbac-serviceaccount | FIX | Rejects valid answers (edit CRB subjects, SA-level automount false) |
| real-1/05-pki-csr | FIX | Key is never checked; 2 minute task with weight 5 |
| real-1/06-apparmor-load | FIX | Test command sends the error to stderr, so "save the output" usually fails; container name not checked |
| real-1/07-seccomp-deploy | FIX | Busywork step "save the type string"; 2 minutes for weight 4 |
| real-1/08-psa-restricted | OK | Good; same task in all three mocks |
| real-1/09-encryption-at-rest | OK | Good, checks etcd content |
| real-1/10-runtimeclass-gvisor | OK | Minor: terminating pods count as "bad" |
| real-1/11-trivy-critical | FIX | "Keep api and tools" guard ignored; deleting all pods scores full |
| real-1/12-static-analysis | OK | Minor: `USER appuser:appuser` is rejected |
| real-1/13-sbom-spdx | FIX | "alpha and gamma unchanged" guard ignored |
| real-1/14-falco-find-pod | FIX | "Other deployments unchanged" guard ignored |
| real-1/15-audit-policy | OK | Good, tests real audit events |
| real-1/16-immutable-container | FIX | "2 replicas ready" passes after setup, so it is never graded |
| real-1/17-apiserver-anon-noderestriction | OK | Good and current (v1 AuthenticationConfiguration) |
| real-2/01-netpol-multi | FIX | "UDP 53 in same namespace" does not reach CoreDNS; text calls it in-cluster DNS |
| real-2/02-netpol-ssh | FIX | All-pods selector not checked; port and ipBlock may be in different rules |
| real-2/03-ingress-tls | OK | Good |
| real-2/04-rbac-serviceaccount | FIX | Copy of real-1/04 (same fix); also duplicate in all mocks |
| real-2/05-pki-csr-san | DROP | Text gives the full command; check passes on CN alone; not a CKS task |
| real-2/06-cis-apiserver-profiling | FIX | Old CIS number (1.2.21 is CIS 1.6; now 1.2.15); checks the file, not the running flag; busywork step |
| real-2/07-aa-read-hosts | FIX | Profile as described cannot start busybox; the /proc/sys deny cannot be seen (already read-only) |
| real-2/08-seccomp-mkdir | FIX | No behaviour test; busywork copy step |
| real-2/09-secret-volume | OK | Good |
| real-2/10-runtimeclass-gvisor | OK | Same as real-1/10 |
| real-2/11-psa-restricted | OK | Same as real-1/08 |
| real-2/12-image-policy-webhook | OK | Good, realistic. Minor: check 6 is a guard |
| real-2/13-trivy-critical | FIX | Copy of real-1/11 |
| real-2/14-static-analysis | OK | Same as real-1/12 |
| real-2/15-falco-rule-output | OK | Good, tests a real alert |
| real-2/16-immutable-container | FIX | Copy of real-1/16 |
| real-2/17-audit-policy | OK | Same as real-1/15 |
| real-3/01-netpol-https-egress | FIX | deny-all-egress content, podSelector and DNS target not checked |
| real-3/02-netpol-metadata | DROP | Same idea as real-3/01 in the same mock; unclear text; DNS demand not checked |
| real-3/03-verify-binaries | FIX | Copy of real-1/03 |
| real-3/04-rbac-serviceaccount | FIX | Copy of real-1/04 |
| real-3/05-pki-cert-key-match | DROP | Text gives the commands; answer is always "mismatch"; not a CKS task |
| real-3/06-hardened-pod | FIX | Container name `app` not checked; overlaps real-1/06 |
| real-3/07-seccomp-mount | FIX | Ready check passes with old pods (never graded); busywork copy step |
| real-3/08-encryption-at-rest | OK | Same as real-1/09 |
| real-3/09-secret-volume | OK | Same as real-2/09 |
| real-3/10-psa-restricted | OK | Same as real-1/08 |
| real-3/11-sbom-spdx | FIX | Copy of real-1/13 |
| real-3/12-static-analysis | OK | Same as real-1/12 |
| real-3/13-trivy-critical | FIX | Copy of real-1/11 |
| real-3/14-falco-find-pod | FIX | Copy of real-1/14 |
| real-3/15-falco-rule-output | OK | Same as real-2/15 |
| real-3/16-immutable-container | FIX | Copy of real-1/16 |
| real-3/17-apiserver-anon-noderestriction | OK | Same as real-1/17 |

Counts: 51 slots. OK 20, FIX 28, DROP 3. The 28 FIX slots need 17 distinct changes (the rest are copies).

## Details for FIX and DROP

### real-1/01-netpol-microseg
- `scripts/01-netpol-microseg/validate.sh`, after line 26, add:
  ```bash
  if [[ "$(echo "$DENY_NP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["spec"].get("podSelector") or {})' 2>/dev/null)" != "{}" ]]; then
    echo "FAIL: deny-all-ingress must select all pods (podSelector: {})"
    exit 1
  fi
  ```
- Optional: lines 46-50 and 62-66 accept only `matchLabels`. Also accept `matchExpressions` with `role In [api]`, or say "use matchLabels" in the text.

### real-1/02-cis-kube-bench-master
Problem: counting `[FAIL]` lines is not a CKS skill, and check 2 passes on any file with one tag line. The real exam asks you to fix named findings.
- `02-cis-kube-bench-master.yaml` lines 6-12, new text:
  "Run kube-bench for the control plane (`kube-bench run --targets master`) and save the output to `/opt/cks3-cis/kube-bench-master.txt`. Fix these FAIL findings: 1.3.2 (kube-controller-manager `--profiling`) and 1.4.1 (kube-scheduler `--profiling`). Both components must run again."
- `setup.sh`: remove `--profiling` lines from `/etc/kubernetes/manifests/kube-controller-manager.yaml` and `kube-scheduler.yaml` (same sed as real-2/06 setup line 8).
- `validate.sh`: keep lines 4-12, but make line 9 require master output: `grep -qE '^\[(PASS|FAIL|WARN|INFO)\] 1\.[1-4]\.' file`. Replace lines 14-29 with two checks: `ps -eo args | grep -E '^kube-controller-manager ' | tr ' ' '\n' | grep -qx -- '--profiling=false'` and the same for `kube-scheduler`, each combined with "pod `kube-controller-manager-controlplane` (or `kube-scheduler-controlplane`) in kube-system is Ready". Weight 5.

### real-1/03-verify-binaries (also real-3/03)
- `scripts/03-verify-binaries/validate.sh` line 15, new condition and message:
  ```bash
  if [[ -e "$D/kubelet" || -e "$D/kube-apiserver" ]] || ! (cd "$D" 2>/dev/null && grep -E ' (kubectl|kubeadm|kube-proxy)$' "$K" | sha512sum -c --quiet - >/dev/null 2>&1) || [[ ! -f "$D/SHA512SUMS.txt" ]]; then
    echo "FAIL: delete only kubelet and kube-apiserver: kubectl, kubeadm, kube-proxy and SHA512SUMS.txt must stay"
  ```
  This check now fails after setup, so `rm *` scores 2/3 and not 3/3.

### real-1/04-rbac-serviceaccount (also real-2/04, real-3/04)
- `validate.sh` line 6: "remove the cluster-wide access" can also be done by removing the subject from the ClusterRoleBinding. New condition:
  ```bash
  if kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{range .subjects[*]}{.kind}/{.namespace}/{.name}{"
"}{end}{end}' 2>/dev/null | grep -qx 'ServiceAccount/ci/deployer' || can '*' '*' -A; then
  ```
- Lines 26-34: also accept `automountServiceAccountToken: false` on the ServiceAccount (valid and common). Add `SAAM=$(kubectl -n ci get sa deployer -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)` and change line 34 to:
  `if [[ "$RUNNING" != "ok" ]] || [[ "$TPL" != "false" && ! ( -z "$TPL" && "$SAAM" == "false" ) ]]; then`
  and the message to "ci-runner pods must not mount a ServiceAccount token (automountServiceAccountToken false on the pod template or the ServiceAccount)".

### real-1/05-pki-csr
- `validate.sh`: the text says "using this key", but no check tests it. After line 15 add:
  ```bash
  if [[ "$(openssl req -in "$CSR" -noout -pubkey 2>/dev/null | openssl pkey -pubin -outform der 2>/dev/null | sha256sum)" != "$(openssl pkey -in /opt/cks-pki/alice.key -pubout -outform der 2>/dev/null | sha256sum)" ]]; then
    echo "FAIL: $CSR was not created from /opt/cks-pki/alice.key"
    exit 1
  fi
  ```
- Realism: an openssl-only CSR is a 2 minute task. Extend the text (lines 8-13) with: "2. Submit it as a Kubernetes `CertificateSigningRequest` named `alice` (signer `kubernetes.io/kube-apiserver-client`), approve it, and save the issued certificate to `/opt/cks-pki/alice.crt`." Setup: `kubectl delete csr alice --ignore-not-found`, `rm -f /opt/cks-pki/alice.crt /opt/cks-pki/alice.csr`. Add checks: `kubectl get csr alice -o jsonpath='{.status.conditions[?(@.type=="Approved")].status}'` is `True`; `openssl verify -CAfile /etc/kubernetes/pki/ca.crt /opt/cks-pki/alice.crt` succeeds and its subject has `CN = alice`. Keep weight 5.

### real-1/06-apparmor-load
- `06-apparmor-load.yaml` lines 18-20: with `kubectl exec ... > file` the shell error goes to stderr, so the file holds only "done" and check 7 fails for a correct answer. New text:
  "run `kubectl exec deny-etc-pod -c deny-etc -- sh -c 'echo test > /etc/blocked' > /opt/cks-apparmor/deny-etc-test.txt 2>&1`"
- `validate.sh` lines 40-43: require the container name: `c.get('name')=='deny-etc' and c.get('securityContext',{})...`.
- `validate.sh` line 61: do not rely only on the saved file. Combine with a live test:
  `if ! grep -qi 'permission denied' /opt/cks-apparmor/deny-etc-test.txt || ! kubectl exec deny-etc-pod -c deny-etc -- sh -c 'echo x > /etc/k16s-probe' 2>&1 | grep -qi 'permission denied'; then`

### real-1/07-seccomp-deploy
- `07-seccomp-deploy.yaml` line 10: delete step 3 (saving the word "RuntimeDefault" tests nothing). Set `weight: 3`.
- `validate.sh`: delete lines 23-31. Lines 8-13 pass after setup, so they are never graded. Fold the rollout into the type check at line 18:
  `[[ "$TYPE" != "RuntimeDefault" ]] || [[ "$(kubectl -n $NS get deploy $DEPLOY -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}/{.spec.replicas}')" != "1/1/1" ]]`
- Optional (better realism): real-1 has no Localhost seccomp task. Make setup place a profile in `/var/lib/kubelet/seccomp/profiles/` and ask for `Localhost` instead.

### real-1/11-trivy-critical (also real-2/13, real-3/13)
- `validate.sh` line 20, new condition and message (fails after setup, so it is graded):
  ```bash
  if ! exists api || ! exists tools || exists web || exists cache || exists proxy; then
    echo "FAIL: delete only the pods with CRITICAL findings: api and tools must stay"
  ```
- Verify once on the lab that `busybox:1.37` and `pause:3.10` show 0 CRITICAL with the bundled DB, and that the DB is pinned (no auto-update), or the answer can change.

### real-1/13-sbom-spdx (also real-3/11)
- `validate.sh` line 26: start the condition with `kubectl -n sbom get deployment beta >/dev/null 2>&1 ||` and change the message to "delete only deployment beta: alpha and gamma must stay unchanged".
- Verify once that `alpine:3.19.1` is the only image with `busybox 1.36.1-r15` (3.18.6 and 3.20.3 must have other revisions).

### real-1/14-falco-find-pod (also real-3/14)
- `validate.sh` line 12: start the condition with `[[ "$R" != "0" ]] ||`, so that scaling everything to 0 costs a point. Message: "scale only the deployment of the pod that reads /etc/shadow: web-cache and collector must still run 1 replica".
- Optional: setup can save the reporter pod name to `/var/lib/k16s/tasks/` and line 17 can compare against it. Now any name of the form `reporter-xxx-yyyyy` passes.

### real-1/16-immutable-container (also real-2/16, real-3/16)
- `validate.sh` line 7 passes after setup, so "all 2 replicas ready" is never graded. Fold the readiness into check 2, line 12:
  `py "s=d['status']; assert s.get('readyReplicas')==2 and s.get('updatedReplicas')==2 and s.get('replicas')==2; sc=t['containers'][0].get('securityContext') or {}; assert sc.get('readOnlyRootFilesystem') is True and sc.get('allowPrivilegeEscalation') is False"`
  Message: "container must set readOnlyRootFilesystem true and allowPrivilegeEscalation false, with 2 ready up-to-date replicas".

### real-2/01-netpol-multi
- `01-netpol-multi.yaml` line 16: UDP 53 "in the same namespace" does not reach CoreDNS (it runs in kube-system), so the policy breaks DNS while the text calls it in-cluster DNS. New text: "Allows **egress** on **UDP and TCP port 53** to pods with label `k8s-app=kube-dns` in namespace `kube-system`". Update the hint (line 21) to "use `namespaceSelector` with `kubernetes.io/metadata.name: kube-system` and a `podSelector` in the same peer".
- `validate.sh` lines 60-68: require a peer with `namespaceSelector.matchLabels['kubernetes.io/metadata.name']=='kube-system'` in the rule that has UDP 53.
- Add after line 72: policyTypes contains both `Ingress` and `Egress` (the text says "deny all other ingress and egress").
- Lines 74-77 (saved file only exists): accept as is, or check that the file parses and has `name: restrict-ingress-egress`.

### real-2/02-netpol-ssh
- `validate.sh` lines 23-40: check port and ipBlock per rule, not across rules, and check the selector:
  ```python
  assert (spec.get('podSelector') or {}) == {}, 'must apply to all pods'
  ok = False
  for r in ingress:
      peers = [p.get('ipBlock', {}) for p in r.get('from', [])]
      ports = [p.get('port') for p in r.get('ports', [])]
      if 22 in ports and any(b.get('cidr') == '203.0.113.0/24' and '203.0.113.128/25' in b.get('except', []) for b in peers):
          ok = True
  assert ok
  ```
- Optional: weight 4 is fine; ~3 minutes.

### real-2/05-pki-csr-san: DROP
Text prints the exact openssl command; the config file is given; check 3 passes on `CN = svc.internal` even without SANs; the IP SAN is not checked. CSR files without the Kubernetes CSR API are not in the v1.37 curriculum. Replace with a Cluster Hardening task (real-2 has only 11% Cluster Hardening): "Restrict access to the Kubernetes API": setup adds a ClusterRoleBinding that gives `system:unauthenticated` read access to secrets and turns on `automountServiceAccountToken` for the `default` ServiceAccount in a namespace; the task is to remove the binding and disable automount. Grade with `kubectl auth can-i --as=system:anonymous` and the ServiceAccount field. Weight 6.

### real-2/06-cis-apiserver-profiling
- Title and line 6: CIS 1.2.21 is the CIS 1.6 number (Kubernetes 1.16-1.18). In cis-2.0 (used by kube-bench for v1.37) profiling is 1.2.15. Change to "CIS 1.2.15" or drop the number.
- `validate.sh` line 4 checks the manifest text, not the running server. Use the running process:
  `ps -eo args | grep -E '^kube-apiserver ' | tr ' ' '\n' | grep -qx -- '--profiling=false' && kubectl get --raw=/readyz >/dev/null 2>&1`
- Delete step 3 (line 10) and lines 9-17 of validate.sh (saving a grep line tests nothing).
- To avoid overlap with the new real-1/02 (controller-manager and scheduler profiling) and to cover the kubelet, consider changing this task to kubelet findings 4.2.1 (anonymous auth) and 4.2.2 (authorization mode not AlwaysAllow) in `/var/lib/kubelet/config.yaml`, graded with `curl -sk https://127.0.0.1:10250/pods` returning 401 and the node Ready. Weight 5.

### real-2/07-aa-read-hosts
- Text lines 10-13 plus the hint describe a profile with only `abstractions/base`, `/etc/hosts r` and `deny /proc/sys/** w`. Under that profile runc cannot exec `/bin/sleep`, so the pod never runs and check 3 fails for a candidate who follows the text. Also `/proc/sys` is already read-only in a normal container, so the deny rule has no visible effect.
- Rework to the common exam shape: setup writes a complete profile to `/opt/cks2-apparmor/profile` whose name inside the file differs from the file name (for example `profile nginx-deny-tmp flags=(attach_disconnected) { #include <abstractions/base> file, network, capability, deny /tmp/** w, }`). Task: load it, find the profile name, apply it to pod `hosts-check` (container `app`, `nodeName: controlplane`). Validate: profile loaded (`aa-status`), pod Running, `appArmorProfile.localhostProfile` on container `app` equals the name, and `kubectl -n apparmor-hosts exec hosts-check -c app -- touch /tmp/x` fails.
- Delete step 4 and validate lines 52-55 (saved YAML only exists).

### real-2/08-seccomp-mkdir
- Delete step 3 (line 18) and validate lines 68-72 (copy only).
- After line 66 add a behaviour check:
  ```bash
  if [[ "$STATUS" != "Running" ]] || kubectl exec seccomp-mkdir -- mkdir /tmp/k16s-probe >/dev/null 2>&1; then
    echo "FAIL: mkdir still works in pod seccomp-mkdir: the profile is not active"
    exit 1
  fi
  ```
- Lines 54-55 read only the first container (`next(...)`); fine for one container. Line 58 matches any name with `block-mkdir`; use equality with `profiles/block-mkdir.json`.

### real-3/01-netpol-https-egress
- `validate.sh` lines 5-8 only check that deny-all-egress exists. Replace with: podSelector is `{}`, `Egress` in policyTypes, and no `egress` rules.
- After line 13 add: allow-external-https `podSelector.matchLabels.app == 'client'`.
- Lines 34-42: require the UDP 53 rule to have a peer with `namespaceSelector.matchLabels['kubernetes.io/metadata.name']=='kube-system'` (the text demands kube-system).
- Text line 13: "internal pod range `10.10.0.0/16`": confirm it matches the lab pod CIDR, or call it "internal range" only.

### real-3/02-netpol-metadata: DROP
Same skill as real-3/01 (0.0.0.0/0 except 169.254.169.254/32) in the same mock. The text is unclear ("allows all other egress" plus a DNS rule that 0.0.0.0/0 already covers), the DNS demand is not checked, and `podSelector: {}` is not checked. Replace with a Cluster Setup task that real-3 lacks, for example an Ingress TLS variant (other names than real-2/03), or Pod-to-Pod encryption if the lab CNI is Cilium.

### real-3/05-pki-cert-key-match: DROP
The text gives the exact commands, the answer is always "mismatch" (setup line 16-17), and comparing moduli is not a CKS curriculum item. Replace with a Cluster Hardening task, for example the CSR API flow from the real-1/05 fix with other names, or a ServiceAccount task: create SA `reports` with `automountServiceAccountToken: false`, mount a projected token with `audience: vault` and `expirationSeconds: 3600` in a pod. Weight 5-6.

### real-3/06-hardened-pod
- `validate.sh` lines 43-46: require `c.get('name')=='app'`. Add image `nginx:alpine` to the Running check at line 10.
- Optional: lower weight to 4 (about 3 minutes). It overlaps real-1/06 (both apply a Localhost AppArmor profile); keep only if real-3 has no other AppArmor task.

### real-3/07-seccomp-mount
- `validate.sh` lines 44-52: `readyReplicas >= 1` passes with the old pod while the new pod fails (for example a missing profile), and it passes after setup, so it is never graded. Fold the rollout into the seccomp check at line 38: also require `updatedReplicas == replicas == readyReplicas` and no `unavailableReplicas`.
- Delete step 4 (line 18) and lines 54-58 (copy only).
- Line 38: match `localhostProfile == 'profiles/block-mount.json'` exactly, not by grep.

## Minor notes on OK tasks (no verdict change)
- real-1/10 (and real-2/10) validate line 22: `bad` also counts pods with `deletionTimestamp`; skip them. Check 4 (line 30) always fails when check 3 fails; acceptable.
- real-1/12 (and copies) validate line 43: also accept `USER appuser:appuser` (`awk '{print $2}' | cut -d: -f1`).
- real-2/12 validate line 52: check 6 passes after setup, so it is never graded. Fold it into check 5 (line 47) with `||`.
- real-2/03: ingress-nginx was retired upstream in 2026. The class name `nginx` is only a name here and no controller is needed, so the task still works.
- real-2/09 has weight 6 and real-3/09 weight 5 for the same task; pick one.

## Mock balance

Curriculum v1.37 weights: Cluster Setup 15, Cluster Hardening 15, System Hardening 10, Minimize Microservice Vulnerabilities 20, Supply Chain 20, Monitoring/Logging/Runtime 20.

| Domain | real-1 | real-2 | real-3 |
|---|---|---|---|
| Cluster Setup | 15 (01,02,03) | 19 (01,02,03,06) | 15 (01,02,03) |
| Cluster Hardening | 17 (04,05,17) | 11 (04,05) | 15 (04,05,17) |
| System Hardening | 10 (06,07) | 11 (07,08) | 11 (06,07) |
| Microservice Vuln. | 18 (08,09,10) | 18 (09,10,11) | 18 (08,09,10) |
| Supply Chain | 19 (11,12,13) | 18 (12,13,14) | 19 (11,12,13) |
| Monitoring/Runtime | 19 (14,15,16) | 19 (15,16,17) | 18 (14,15,16) |
| Total weight | 98 | 96 | 96 |

Weights are close to the curriculum. real-2 is low on Cluster Hardening and high on Cluster Setup: the real-2/05 replacement should be Cluster Hardening with weight 6-7.

Duplicates across mocks (byte-identical scripts): RBAC SA (all 3), PSA restricted (all 3), immutable container (all 3), static analysis (all 3), trivy critical (all 3), gVisor (1, 2), encryption at rest (1, 3), verify binaries (1, 3), SBOM (1, 3), Falco find pod (1, 3), Falco rule output (2, 3), audit policy (1, 2), anonymous auth (1, 3), secret volume (2, 3). A candidate who has done real-1 has seen 11 of 17 tasks in real-3. Suggestion: write variants (other names, level `baseline` instead of `restricted`, other verbs, other image set) for the five tasks that are in all three mocks first.

Curriculum items with no task in any mock: Pod-to-Pod encryption (Cilium, Istio), Upgrade Kubernetes, sign and validate artifacts (cosign) or permitted registries outside ImagePolicyWebhook, minimize host OS footprint, kubelet hardening (covered if real-2/06 moves to the kubelet). These go to the backlog.

#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

# Remove kube-apiserver flags (by prefix) and hostPath volumes (by path prefix)
# left over from an earlier attempt. Prints "changed" when the manifest changed.
strip_apiserver() {
  python3 - "$@" <<'PY'
import sys, yaml
M = "/etc/kubernetes/manifests/kube-apiserver.yaml"
flags = [a for a in sys.argv[1:] if a.startswith("--")]
paths = [a for a in sys.argv[1:] if a.startswith("/")]
d = yaml.safe_load(open(M))
c = d["spec"]["containers"][0]
before = yaml.safe_dump(d)
c["command"] = [x for x in c["command"] if not any(x.startswith(f) for f in flags)]
vols = d["spec"].get("volumes", [])
drop = {v["name"] for v in vols if any(v.get("hostPath", {}).get("path", "").startswith(p) for p in paths)}
d["spec"]["volumes"] = [v for v in vols if v["name"] not in drop]
c["volumeMounts"] = [m for m in c.get("volumeMounts", []) if m["name"] not in drop]
if yaml.safe_dump(d) != before:
    open(M, "w").write(yaml.safe_dump(d, default_flow_style=False, sort_keys=False))
    print("changed")
PY
}

# Wait until kubelet has started a new kube-apiserver process and it is ready.
wait_apiserver_restart() {
  local old="$1" new
  for _ in $(seq 1 100); do
    new=$(pgrep -xo kube-apiserver || true)
    if [[ -n "$new" && "$new" != "$old" ]] && kubectl get --raw=/readyz >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "warning: kube-apiserver did not come back in time" >&2
  return 0
}

D=/etc/k16s/image-bouncer
P=/etc/kubernetes/policywebhook
mkdir -p "$D" "$P"

# Reset an earlier attempt: plugin flag value and config file flag.
OLD=$(pgrep -xo kube-apiserver || true)
M=/etc/kubernetes/manifests/kube-apiserver.yaml
CHANGED=no
if grep -q -- '--admission-control-config-file' "$M"; then
  [[ "$(strip_apiserver --admission-control-config-file /etc/kubernetes/policywebhook)" == "changed" ]] && CHANGED=yes
fi
if grep -q -- '--enable-admission-plugins=.*ImagePolicyWebhook' "$M"; then
  sed -i -E '/--enable-admission-plugins=/{s/,ImagePolicyWebhook//; s/ImagePolicyWebhook,//}' "$M"
  CHANGED=yes
fi
[[ "$CHANGED" == "yes" ]] && wait_apiserver_restart "$OLD"

# Backend: CA + server cert, review service on 127.0.0.1:8443.
if [[ ! -f "$D/server.crt" ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=image-bouncer-ca" \
    -keyout "$D/ca.key" -out "$D/ca.crt" 2>/dev/null
  openssl req -newkey rsa:2048 -nodes -subj "/CN=image-bouncer.k16s.local" \
    -keyout "$D/server.key" -out "$D/server.csr" 2>/dev/null
  printf "subjectAltName=DNS:image-bouncer.k16s.local,IP:127.0.0.1\n" > "$D/san.ext"
  openssl x509 -req -in "$D/server.csr" -CA "$D/ca.crt" -CAkey "$D/ca.key" -CAcreateserial \
    -days 3650 -extfile "$D/san.ext" -out "$D/server.crt" 2>/dev/null
  chmod 600 "$D"/*.key
fi
echo team-red > "$D/namespaces"
cat > /usr/local/bin/k16s-image-bouncer <<'PYEOF'
#!/usr/bin/env python3
# k16s image review backend for the ImagePolicyWebhook task.
# Denies images with the "latest" tag (or no tag) in the namespaces listed in
# /etc/k16s/image-bouncer/namespaces; allows every other image.
import json, ssl
from http.server import BaseHTTPRequestHandler, HTTPServer

D = "/etc/k16s/image-bouncer"

def strict_namespaces():
    try:
        return {l.strip() for l in open(D + "/namespaces") if l.strip()}
    except OSError:
        return set()

def bad(image):
    name = image.split("@")[0]
    last = name.rsplit("/", 1)[-1]
    return ":" not in last or last.endswith(":latest")

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        spec = body.get("spec", {})
        ns = spec.get("namespace", "")
        images = [c.get("image", "") for c in spec.get("containers", [])]
        denied = [i for i in images if ns in strict_namespaces() and bad(i)]
        status = {"allowed": not denied}
        if denied:
            status["reason"] = "images with the latest tag are not allowed: " + ", ".join(denied)
        out = json.dumps({"apiVersion": body.get("apiVersion", "imagepolicy.k8s.io/v1alpha1"),
                          "kind": "ImageReview", "status": status}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)
    def log_message(self, *a):
        pass

srv = HTTPServer(("127.0.0.1", 8443), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(D + "/server.crt", D + "/server.key")
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
PYEOF
chmod 755 /usr/local/bin/k16s-image-bouncer
cat > /etc/systemd/system/k16s-image-bouncer.service <<'EOF'
[Unit]
Description=k16s image review backend (ImagePolicyWebhook task)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/k16s-image-bouncer
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable k16s-image-bouncer >/dev/null 2>&1
systemctl restart k16s-image-bouncer
grep -q 'image-bouncer.k16s.local' /etc/hosts || echo "127.0.0.1 image-bouncer.k16s.local" >> /etc/hosts

# Incomplete configuration for the candidate.
cp "$D/ca.crt" "$P/webhook-ca.crt"
cat > "$P/admission_config.yaml" <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/policywebhook/kubeconf
      allowTTL: 30
      denyTTL: 30
      retryBackoff: 500
      defaultAllow: true
EOF
cat > "$P/kubeconf" <<'EOF'
apiVersion: v1
kind: Config
clusters:
- name: image-bouncer
  cluster:
    certificate-authority: /etc/kubernetes/policywebhook/webhook-ca.crt
    server: https://CHANGE-ME
contexts:
- name: image-bouncer
  context:
    cluster: image-bouncer
    user: api-server
current-context: image-bouncer
users:
- name: api-server
  user: {}
EOF
kubectl create namespace team-red --dry-run=client -o yaml | kubectl apply -f -
echo "Environment ready: config in /etc/kubernetes/policywebhook, backend at https://image-bouncer.k16s.local:8443/review"

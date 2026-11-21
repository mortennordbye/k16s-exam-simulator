#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
LOG=/var/log/falco/alerts.log

if ! systemctl is-active -q falco; then
  echo "FAIL: the falco service is not running"
  exit 1
fi

BEFORE=$(wc -l < "$LOG" 2>/dev/null || echo 0)
for i in 1 2 3; do
  kubectl -n falco-lab exec probe -- cat /etc/shadow >/dev/null 2>&1
  sleep 2
done
NEW=""
for i in $(seq 1 8); do
  NEW=$(tail -n +"$((BEFORE + 1))" "$LOG" 2>/dev/null)
  [[ "$NEW" == *"/etc/shadow"* ]] && break
  sleep 1
done

if [[ ! -f "$LOG" ]] || [[ "$NEW" != *"/etc/shadow"* ]]; then
  echo "FAIL: reading /etc/shadow in pod falco-lab/probe creates no alert in $LOG"
  exit 1
fi

if ! echo "$NEW" | grep -qE 'SENSITIVE-READ file=/etc/shadow user=root pod=probe ns=falco-lab'; then
  echo "FAIL: the alert in $LOG is not in the format SENSITIVE-READ file=... user=... pod=... ns=..."
  exit 1
fi

if ! grep -q 'SENSITIVE-READ' /etc/falco/falco_rules.local.yaml /etc/falco/rules.d/* 2>/dev/null || grep -q 'SENSITIVE-READ' /etc/falco/falco_rules.yaml 2>/dev/null; then
  echo "FAIL: the rule change must be in /etc/falco/falco_rules.local.yaml, not in falco_rules.yaml"
  exit 1
fi

echo "PASS: Falco writes alerts to $LOG with the new output of Read sensitive file untrusted"

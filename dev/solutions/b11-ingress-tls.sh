#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n shop create secret tls shop-tls --cert=/opt/cks-ingress/shop.crt --key=/opt/cks-ingress/shop.key
kubectl -n shop create ingress shop-ingress --class=nginx --rule="shop.k16s.local/*=shop-svc:80,tls=shop-tls"

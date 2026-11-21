#!/usr/bin/env bash
cd /opt/candidate-binaries
sha512sum -c SHA512SUMS.txt 2>/dev/null | awk -F': ' '$2!="OK"{print $1}' | xargs -r rm -v

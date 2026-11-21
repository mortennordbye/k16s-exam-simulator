package main

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func writeScript(t *testing.T, body string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "validate.sh")
	if err := os.WriteFile(p, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestRunValidatePartial(t *testing.T) {
	p := writeScript(t, `#!/usr/bin/env bash
set -eo pipefail
if ! true; then
  echo "FAIL: one"
  exit 1
fi
if ! false; then
  echo "FAIL: two"
  exit 1
fi
check() { if ! [ -n "x" ]; then echo "FAIL: three"; exit 1; fi; }
check
false
echo "PASS: all good"
`)
	r := runValidate(context.Background(), p)
	if r.Total != 3 || r.Checks != 2 || r.Passed {
		t.Fatalf("want 2/3 not passed, got %d/%d passed=%v out=%q", r.Checks, r.Total, r.Passed, r.Output)
	}
	if len(r.Failed) != 1 || r.Failed[0] != "two" {
		t.Fatalf("want failed [two], got %v", r.Failed)
	}
	if contains(r.Output, "PASS: all good") {
		t.Fatalf("summary PASS line must be hidden after a failure: %q", r.Output)
	}
}

func TestRunValidateAllPass(t *testing.T) {
	p := writeScript(t, "#!/usr/bin/env bash\nset -e\nif ! true; then\n  echo \"FAIL: x\"\n  exit 1\nfi\necho \"PASS: ok\"\n")
	r := runValidate(context.Background(), p)
	if !r.Passed || r.Checks != 1 || r.Total != 1 {
		t.Fatalf("want pass 1/1, got %+v", r)
	}
}

func contains(s, sub string) bool { return len(s) >= len(sub) && (s == sub || len(sub) == 0 || indexOf(s, sub) >= 0) }
func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

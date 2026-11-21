package main

import (
	"context"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// CKS hub: partial scoring.
//
// Check scripts follow one convention: every check is
//   if ! <cond>; then echo "FAIL: <msg>"; exit 1; fi
// and the script ends with echo "PASS: <summary>". Upstream treats the first
// FAIL as the end of grading (all or nothing). Here the script runs inside a
// wrapper that turns "exit <non-zero>" into "count one failed check and go
// on", so every check runs. The number of checks is the number of FAIL
// messages in the script. Points = weight * passed / total, like the real
// exam, where partial work earns partial points.

type CheckResult struct {
	Passed      bool     `json:"passed"`
	Checks      int      `json:"checks_passed"`
	Total       int      `json:"checks_total"`
	Failed      []string `json:"failed"`
	Output      string   `json:"output"`
	FailedSites []int    `json:"-"`
}

var (
	failSiteRe = regexp.MustCompile(`echo\s+["']?FAIL`)
	setERe     = regexp.MustCompile(`(?m)^(\s*)set\s+-([a-zA-Z]+)(.*)$`)
	markerRe   = regexp.MustCompile(`(?m)^__K16S__ failed=(\d+)\s*$`)
	// Each FAIL message gets its site number (FAIL@3:) so a check can be
	// tracked between runs. The number is removed before display.
	failEchoRe = regexp.MustCompile(`(echo\s+["']?)FAIL:`)
	siteRe     = regexp.MustCompile(`^FAIL@(\d+):\s*`)
)

const validatePreamble = `__K16S_FAILS=0
exit() {
  if [ "${1:-0}" != "0" ]; then __K16S_FAILS=$((__K16S_FAILS+1)); return 0; fi
  builtin exit 0
}
trap 'echo "__K16S__ failed=$__K16S_FAILS"; builtin exit $(( __K16S_FAILS > 0 ? 1 : 0 ))' EXIT
`

// wrapValidate removes "set -e" (a failing command must not end grading)
// and adds the counting preamble after the shebang.
func wrapValidate(src string) string {
	src = setERe.ReplaceAllStringFunc(src, func(line string) string {
		m := setERe.FindStringSubmatch(line)
		flags := strings.ReplaceAll(m[2], "e", "")
		if flags == "" {
			if strings.TrimSpace(m[3]) == "" {
				return m[1] + ":"
			}
			return m[1] + "set" + m[3]
		}
		return m[1] + "set -" + flags + m[3]
	})
	n := 0
	src = failEchoRe.ReplaceAllStringFunc(src, func(m string) string {
		n++
		sub := failEchoRe.FindStringSubmatch(m)
		return sub[1] + "FAIL@" + strconv.Itoa(n) + ":"
	})
	if strings.HasPrefix(src, "#!") {
		if i := strings.Index(src, "\n"); i >= 0 {
			return src[:i+1] + validatePreamble + src[i+1:]
		}
	}
	return validatePreamble + src
}

func runValidate(parent context.Context, script string) CheckResult {
	raw, err := os.ReadFile(script)
	if err != nil {
		return CheckResult{Total: 1, Output: "cannot read check script: " + err.Error()}
	}
	total := len(failSiteRe.FindAllIndex(raw, -1))
	if total < 1 {
		total = 1
	}

	tmp, err := os.CreateTemp("", "k16s-validate-*.sh")
	if err != nil {
		return CheckResult{Total: total, Output: err.Error()}
	}
	defer os.Remove(tmp.Name())
	tmp.WriteString(wrapValidate(string(raw)))
	tmp.Close()

	ctx, cancel := context.WithTimeout(parent, 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "bash", tmp.Name())
	cmd.Env = append(os.Environ(), "KUBECONFIG=/etc/kubernetes/admin.conf")
	outB, runErr := cmd.CombinedOutput()
	out := string(outB)

	failed := total // no marker = crash or timeout: nothing proven
	if m := markerRe.FindStringSubmatch(out); m != nil {
		failed, _ = strconv.Atoi(m[1])
	}
	out = markerRe.ReplaceAllString(out, "")

	var fails []string
	var kept []string
	var sites []int
	seen := map[int]bool{}
	for _, l := range strings.Split(strings.TrimRight(out, "\n"), "\n") {
		t := strings.TrimSpace(l)
		if m := siteRe.FindStringSubmatch(t); m != nil {
			id, _ := strconv.Atoi(m[1])
			if !seen[id] {
				seen[id] = true
				sites = append(sites, id)
			}
			t = "FAIL: " + siteRe.ReplaceAllString(t, "")
			l = t
		}
		if strings.HasPrefix(t, "FAIL:") {
			fails = append(fails, strings.TrimSpace(strings.TrimPrefix(t, "FAIL:")))
		}
		// The summary PASS line is printed even after failures; hide it then.
		if failed > 0 && strings.HasPrefix(t, "PASS:") {
			continue
		}
		kept = append(kept, l)
	}
	passedChecks := total - failed
	if passedChecks < 0 {
		passedChecks = 0
	}
	all := runErr == nil && failed == 0
	if all {
		passedChecks = total
	}
	return CheckResult{
		Passed:      all,
		Checks:      passedChecks,
		Total:       total,
		Failed:      fails,
		Output:      strings.TrimSpace(strings.Join(kept, "\n")),
		FailedSites: sites,
	}
}

// applyBaseline scores only the checks that failed right after setup (the
// work the task asks for). Checks that already passed after setup ("the pod
// exists") give no points, like the real exam. Without a baseline the plain
// count stays.
func applyBaseline(r CheckResult, baseline []int) CheckResult {
	if len(baseline) == 0 {
		return r
	}
	if r.Passed {
		r.Checks, r.Total = len(baseline), len(baseline)
		return r
	}
	if len(r.FailedSites) == 0 { // could not track sites: keep plain count
		return r
	}
	now := map[int]bool{}
	for _, s := range r.FailedSites {
		now[s] = true
	}
	p := 0
	for _, b := range baseline {
		if !now[b] {
			p++
		}
	}
	r.Checks, r.Total = p, len(baseline)
	return r
}

func sitesString(s []int) string {
	parts := make([]string, len(s))
	for i, v := range s {
		parts[i] = strconv.Itoa(v)
	}
	return strings.Join(parts, " ")
}

func parseSites(s string) []int {
	var out []int
	for _, f := range strings.Fields(s) {
		if v, err := strconv.Atoi(f); err == nil {
			out = append(out, v)
		}
	}
	return out
}

func statusFor(r CheckResult) string {
	switch {
	case r.Passed || (r.Total > 0 && r.Checks == r.Total):
		return "passed"
	case r.Checks > 0:
		return "partial"
	default:
		return "failed"
	}
}

// jobMu serialises background prepare (exam start) and grading (exam end),
// so grading never runs while a task is still being set up.
var jobMu sync.Mutex

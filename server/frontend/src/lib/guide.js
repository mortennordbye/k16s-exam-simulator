// CKS hub: per-task guide built from 07-scaffolds.md (synced to guide.md by "make guide").
import raw from './guide.md?raw';

const PIPE = '@@PIPE@@';
const sections = {};
for (const part of raw.split(/^### /m).slice(1)) {
  const nl = part.indexOf('\n');
  const title = part.slice(0, nl).trim();
  const num = title.split(' ')[0];
  let body = part.slice(nl + 1).split(/^## /m)[0];
  const manifests = [];
  body = body.replace(/\*\*Manifest\*\* `([^`]+)`[^\n]*\n```\w*\n([\s\S]*?)```\n?/g, (_, name, code) => {
    manifests.push({ name, code: code.replace(/\n$/, '') });
    return '';
  });
  sections[num] = { num, title: title.slice(num.length).trim(), body: body.trim(), manifests };
}

// Task id keywords -> scaffold sections. First match wins.
const rules = [
  [/hardened-pod/, ['2.2', '6.1', '6.2']],
  [/netpol/, ['1.1', '1.2', '1.3', '1.4']],
  [/apparmor|(^|-)aa-/, ['6.1']],
  [/seccomp/, ['6.2', '2.2']],
  [/pki/, ['4.5']],
  [/kube-bench/, ['1.9']],
  [/kubelet/, ['1.7', '1.9']],
  [/apiserver|controller-manager|etcd|cis/, ['4.3', '1.9']],
  [/rbac|role/, ['4.1']],
  [/serviceaccount|-sa-/, ['4.2']],
  [/audit/, ['3.1', '4.3']],
  [/encrypt/, ['2.4', '4.3']],
  [/runtimeclass|gvisor|sandbox/, ['2.6']],
  [/falco/, ['3.2']],
  [/ingress-tls|tls/, ['1.6']],
  [/psa|pod-security/, ['2.1']],
];

export function guideFor(id = '') {
  const key = id.toLowerCase();
  for (const [re, nums] of rules) {
    if (re.test(key)) return nums.map((n) => sections[n]).filter(Boolean);
  }
  return ['0.1', '0.2'].map((n) => sections[n]).filter(Boolean);
}

const esc = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function inline(t) {
  return esc(t)
    .split(/(`[^`]+`)/)
    .map((p) => {
      if (p.startsWith('`') && p.endsWith('`') && p.length > 1) {
        return '<code class="bg-[#2a2f42] px-1 rounded text-slate-200">' + p.slice(1, -1) + '</code>';
      }
      return p
        .replace(/\*\*([^*]+)\*\*/g, '<strong class="text-slate-200">$1</strong>')
        .replace(/(https?:\/\/[^\s<)]+)/g, '<a href="$1" target="_blank" rel="noopener" class="text-[#3b82f6] underline break-all">$1</a>');
    })
    .join('');
}

export function renderGuide(body) {
  const out = [];
  const lines = body.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith('```')) {
      const code = [];
      while (++i < lines.length && !lines[i].startsWith('```')) code.push(lines[i]);
      out.push('<pre class="bg-[#161922] text-slate-200 p-2 rounded overflow-x-auto text-[11px] leading-snug select-all">' + esc(code.join('\n')) + '</pre>');
    } else if (line.startsWith('|')) {
      if (/^\|[\s|:-]*\|$/.test(line)) continue;
      const cells = line.split('\\|').join(PIPE).split('|').slice(1, -1).map((c) => c.split(PIPE).join('|').trim());
      if (cells.length === 2) {
        out.push('<div class="grid grid-cols-[5.5rem_1fr] gap-2 py-1 border-b border-[#4a5068]"><span class="text-slate-500">' + inline(cells[0]) + '</span><span>' + inline(cells[1]) + '</span></div>');
      } else {
        out.push('<div class="py-1 border-b border-[#4a5068]">' + cells.map(inline).join(' &middot; ') + '</div>');
      }
    } else if (line.startsWith('- ')) {
      out.push('<div class="pl-3">&bull; ' + inline(line.slice(2)) + '</div>');
    } else if (line.trim()) {
      out.push('<p class="my-1">' + inline(line) + '</p>');
    }
  }
  return out.join('');
}

// All full manifests for a task, without duplicates, in section order.
export function manifestsFor(id = '') {
  const seen = new Set();
  const out = [];
  for (const s of guideFor(id)) {
    for (const m of s.manifests ?? []) {
      if (!seen.has(m.name)) { seen.add(m.name); out.push(m); }
    }
  }
  return out;
}

<script>
  import { onMount, onDestroy } from 'svelte';
  import { api } from '$lib/api.js';
  import { guideFor, renderGuide, manifestsFor } from '$lib/guide.js'; // CKS hub

  // ── State ──────────────────────────────────────────────────────────────────
  let view       = $state('loading'); // loading | home | exam | results
  let mode       = $state('heavy'); // heavy | lightweight — from /api/status
  let profile    = $state('cka');
  let duration   = $state(7200);
  let session    = $state(null);
  let questions  = $state([]);
  let profiles   = $state([]);
  let currentIdx = $state(0);
  let checking   = $state(false);
  let setting_up = $state(false);
  let checkResult = $state(null);
  let timeLeft   = $state(0);
  let error      = $state('');

  let timerInterval = null;
  // CKS hub: real exam mode, flags, polling
  let examMode  = $state(true);
  let flagged   = $state({});
  let pollTimer = null;
  let isExam    = $derived(!!session?.exam_mode);
  function flagKey() { return 'k16s-flags-' + (session?.id ?? ''); }
  function toggleFlag(q) {
    flagged = { ...flagged, [q.id]: !flagged[q.id] };
    try { localStorage.setItem(flagKey(), JSON.stringify(flagged)); } catch {}
  }
  function loadFlags() {
    try { flagged = JSON.parse(localStorage.getItem(flagKey()) || '{}'); } catch { flagged = {}; }
  }
  function stopPoll() { clearInterval(pollTimer); pollTimer = null; }
  function pollActive() {
    stopPoll();
    pollTimer = setInterval(async () => {
      try { session = await api.get('/api/session'); } catch {}
    }, 4000);
  }
  function pollGrading() {
    stopPoll();
    const tick = async () => {
      try {
        const s = await api.get('/api/session/last');
        session = s;
        if (s.graded_at) stopPoll();
      } catch {}
    };
    tick();
    pollTimer = setInterval(tick, 3000);
  }
  let terminalIframe = $state(null);
  let rightPanel = $state('desktop'); // terminal | desktop (CKS hub: desktop first, like the real exam)
  let desktopLoaded = $state(true);

  // CKS hub: click-to-copy, like the real exam. Sends text to the noVNC
  // desktop clipboard (same-origin iframe) and to the Mac clipboard.
  let copiedMsg = $state('');
  // CKS hub: draggable divider between question panel and desktop.
  let leftPct = $state(25);
  let dragging = $state(false);
  function startDrag(e) {
    dragging = true;
    const move = (ev) => {
      leftPct = Math.min(60, Math.max(15, (ev.clientX / window.innerWidth) * 100));
    };
    const up = () => {
      dragging = false;
      try { localStorage.setItem('k16s-left-pct', String(Math.round(leftPct))); } catch {}
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    e.preventDefault();
  }
  function sendToDesktop(text) {
    if (!text) return;
    try {
      const doc = document.querySelector('iframe[title="Desktop"]')?.contentDocument;
      const ta = doc?.getElementById('noVNC_clipboard_text');
      if (ta) { ta.value = text; ta.dispatchEvent(new Event('change')); }
    } catch (e) { /* desktop not loaded yet */ }
  }
  function copyClick(e) {
    const el = e.target.closest('code, pre');
    if (!el || e.target.closest('a')) return;
    const text = el.innerText.trim();
    navigator.clipboard?.writeText(text).catch(() => {});
    sendToDesktop(text);
    el.classList.add('ring-2', 'ring-green-400');
    setTimeout(() => el.classList.remove('ring-2', 'ring-green-400'), 600);
    copiedMsg = 'Copied: ' + (text.length > 40 ? text.slice(0, 40) + '...' : text);
    setTimeout(() => (copiedMsg = ''), 1500);
  }
  function onCopy() {
    const t = window.getSelection()?.toString();
    if (t) sendToDesktop(t);
  }

  function selectPanel(p) {
    rightPanel = p;
    if (p === 'desktop') desktopLoaded = true;
  }

  // ── Derived ────────────────────────────────────────────────────────────────
  let currentQuestion = $derived(questions[currentIdx] ?? null);
  let progress        = $derived(session?.progress ?? {});

  function unavailableInThisMode(q) {
    return mode === 'lightweight' && q.requires === 'heavy';
  }
  let currentUnavailable = $derived(currentQuestion ? unavailableInThisMode(currentQuestion) : false);

  // Questions that can't run in this mode are excluded from both sides of
  // the score fraction — otherwise a lightweight-mode candidate could never
  // reach 100% no matter how well they do on what's actually available.
  let scorableQuestions = $derived(questions.filter(q => !unavailableInThisMode(q)));
  // Partial scoring: weight x passed checks / total checks.
  function pointsFor(q) {
    const p = progress[q.id];
    if (!p) return 0;
    if (p.status === 'passed') return q.weight;
    if (p.checks_total > 0) return (q.weight * p.checks_passed) / p.checks_total;
    return 0;
  }
  let score = $derived(Math.round(scorableQuestions.reduce((acc, q) => acc + pointsFor(q), 0) * 10) / 10);
  let totalPoints = $derived(scorableQuestions.reduce((acc, q) => acc + q.weight, 0));

  // CKS hub: CKS only. Real exam mocks (cks-real-*) and topic drills (cks, cks2, cks3).
  let ckaProfiles = $derived([]);
  let realProfiles = $derived(profiles.filter(p => p.startsWith('cks-real')).sort());
  let cksProfiles = $derived(profiles.filter(p => p.startsWith('cks') && !p.startsWith('cks-real') && p !== 'cks-bank').sort());
  function weightPct(q) { return Math.round((q.weight / (totalPoints || 1)) * 100); }

  function labelFor(p, group) {
    const sorted = [...group].sort();
    const prefix = p.startsWith('cks-real') ? 'Mock' : p.startsWith('cka') ? 'CKA' : 'Drill';
    return `${prefix} ${sorted.indexOf(p) + 1}`;
  }

  function examLabel(p) {
    if (p.startsWith('cks-real')) return 'CKS ' + labelFor(p, realProfiles);
    return 'CKS ' + labelFor(p, cksProfiles);
  }

  let timeClass = $derived(
    timeLeft < 300 ? 'text-red-400 animate-pulse' :
    timeLeft < 600 ? 'text-amber-400' :
    'text-slate-200'
  );

  // ── Helpers ────────────────────────────────────────────────────────────────
  function fmt(secs) {
    const h = Math.floor(secs / 3600).toString().padStart(2, '0');
    const m = Math.floor((secs % 3600) / 60).toString().padStart(2, '0');
    const s = (secs % 60).toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  }

  function statusClass(q) {
    if (unavailableInThisMode(q)) return 'bg-[#4a5169] text-slate-600 ring-[#6b7392] opacity-50 line-through decoration-slate-600';
    if (isExam && !session?.ended_at) {
      return flagged[q.id] ? 'bg-amber-700 text-amber-100 ring-amber-500' : 'bg-[#4a5169] text-slate-300 ring-[#6b7392]';
    }
    const s = progress[q.id]?.status;
    if (s === 'partial')  return 'bg-yellow-700 text-yellow-100 ring-yellow-600';
    if (s === 'passed')   return 'bg-green-700 text-green-100 ring-green-600';
    if (s === 'failed')   return 'bg-red-800   text-red-100   ring-red-700';
    if (s === 'attempted') return 'bg-amber-700 text-amber-100 ring-amber-600';
    return 'bg-[#4a5169] text-slate-400 ring-[#6b7392]';
  }

  function md(text) {
    if (!text) return '';
    let s = text
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    // Fenced code blocks
    s = s.replace(/```[\w]*\n([\s\S]*?)```/g, '<pre><code>$1</code></pre>');
    // Inline code
    s = s.replace(/`([^`\n]+)`/g, '<code>$1</code>');
    // Bold
    s = s.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>');
    // Lists
    const lines = s.split('\n');
    let html = '';
    let inList = false;
    for (const line of lines) {
      if (/^- /.test(line)) {
        if (!inList) { html += '<ul class="list-disc pl-5 space-y-1 my-2">'; inList = true; }
        html += `<li>${line.slice(2)}</li>`;
      } else {
        if (inList) { html += '</ul>'; inList = false; }
        if (line.trim() === '') {
          html += '<br>';
        } else if (!line.startsWith('<pre>')) {
          html += `<p>${line}</p>`;
        } else {
          html += line;
        }
      }
    }
    if (inList) html += '</ul>';
    return html;
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  function startTimer() {
    clearInterval(timerInterval);
    timerInterval = setInterval(() => {
      if (!session) return;
      const elapsed = Math.floor((Date.now() - new Date(session.started_at).getTime()) / 1000);
      timeLeft = Math.max(0, session.duration_secs - elapsed);
      if (timeLeft === 0) endExam();
    }, 1000);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  onMount(async () => {
    try {
      const status = await api.get('/api/status');
      profiles = status.profiles ?? [];
      mode = status.mode ?? 'heavy';
      const real = profiles.filter(p => p.startsWith('cks-real')).sort();
      profile = real[0] ?? 'cks';
      if (status.session) {
        session = status.session;
        loadFlags();
        const data = await api.get('/api/questions?profile=' + session.profile);
        questions = data.questions ?? [];
        if (session.ended_at) {
          view = 'results';
        } else {
          view = 'exam';
          startTimer();
          if (session.exam_mode) pollActive();
        }
      } else {
        view = 'home';
      }
    } catch (e) {
      error = e.message;
      view = 'home';
    }
  });

  onMount(() => {
    document.addEventListener('copy', onCopy); // CKS hub
    const saved = Number(localStorage.getItem('k16s-left-pct'));
    if (saved >= 15 && saved <= 60) leftPct = saved;
  });
  onDestroy(() => { clearInterval(timerInterval); stopPoll(); document.removeEventListener('copy', onCopy); });

  // ── Actions ────────────────────────────────────────────────────────────────
  async function startExam() {
    error = '';
    try {
      const resp = await api.post('/api/session/start', { profile, duration_secs: duration, exam_mode: examMode });
      session = resp.session;
      loadFlags();
      if (session.exam_mode) pollActive();
      const data = await api.get('/api/questions?profile=' + profile);
      questions = data.questions ?? [];
      currentIdx = 0;
      checkResult = null;
      view = 'exam';
      startTimer();
    } catch (e) {
      error = e.message;
    }
  }

  async function checkAnswer() {
    if (!currentQuestion || checking || currentUnavailable) return;
    checking = true;
    checkResult = null;
    try {
      const result = await api.post('/api/questions/' + currentQuestion.id + '/check', {});
      checkResult = result.unavailable ? { unavailable: true, output: result.reason } : result;
      session = await api.get('/api/session');
    } catch (e) {
      checkResult = { passed: false, output: e.message };
    } finally {
      checking = false;
    }
  }

  async function setupEnv() {
    if (!currentQuestion || setting_up || currentUnavailable) return;
    setting_up = true;
    checkResult = null;
    try {
      const result = await api.post('/api/questions/' + currentQuestion.id + '/setup', {});
      checkResult = result.unavailable
        ? { unavailable: true, output: result.reason, isSetup: true }
        : { passed: result.ok, output: result.output, isSetup: true };
      session = await api.get('/api/session');
    } catch (e) {
      checkResult = { passed: false, output: e.message, isSetup: true };
    } finally {
      setting_up = false;
    }
  }

  async function endExam() {
    clearInterval(timerInterval);
    try {
      const resp = await api.post('/api/session/end', {});
      session = resp.session;
    } catch (e) {
      // Session may have already ended (timer ran out and we already called endExam)
    }
    view = 'results';
    pollGrading();
  }

  function selectQuestion(idx) {
    currentIdx = idx;
    checkResult = null;
  }

  async function newExam() {
    stopPoll();
    session = null;
    questions = [];
    checkResult = null;
    view = 'home';
  }
</script>

<!-- ── Loading ─────────────────────────────────────────────────────────── -->
{#if view === 'loading'}
  <div class="h-screen flex items-center justify-center">
    <div class="text-slate-400 text-sm">Connecting…</div>
  </div>

<!-- ── Home / Start ────────────────────────────────────────────────────── -->
{:else if view === 'home'}
  <div class="h-screen flex flex-col items-center justify-center gap-8 px-4">
    <div class="text-center">
      <img src="/logo.svg" alt="K16S" class="h-12 mx-auto mb-1" />
      <div class="text-slate-400 text-sm tracking-widest uppercase">Kubernetes Exam Practice</div>
    </div>

    {#if error}
      <div class="text-red-400 text-sm bg-red-950/40 border border-red-900 rounded px-4 py-2 max-w-sm text-center">
        {error}
      </div>
    {/if}

    <div class="bg-[#3b4256] border border-[#5a6280] rounded-lg p-6 w-full max-w-sm space-y-5">
      <div>
        <div class="block text-xs text-slate-400 uppercase tracking-wider mb-1.5">Exam Profile</div>
        <div class="flex gap-2">
          {#if ckaProfiles.length}
            <div class="flex-1 border border-[#5a6280] rounded-md px-2 pt-1.5 pb-2 space-y-1.5">
              <div class="text-[10px] text-slate-500 uppercase tracking-widest text-center">CKA</div>
              <div class="flex gap-1.5">
                {#each ckaProfiles.sort() as p}
                  <button
                    onclick={() => profile = p}
                    class="flex-1 py-1.5 rounded text-sm font-medium transition-colors {profile === p
                      ? 'bg-[#3b82f6] text-white'
                      : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
                  >{labelFor(p, ckaProfiles)}</button>
                {/each}
              </div>
            </div>
          {/if}
          {#if realProfiles.length}
            <div class="flex-1 border border-[#5a6280] rounded-md px-2 pt-1.5 pb-2 space-y-1.5">
              <div class="text-[10px] text-slate-500 uppercase tracking-widest text-center">CKS mock exams (v1.37)</div>
              <div class="flex gap-1.5">
                {#each realProfiles as p}
                  <button
                    onclick={() => profile = p}
                    class="flex-1 py-1.5 rounded text-sm font-medium transition-colors {profile === p
                      ? 'bg-[#3b82f6] text-white'
                      : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
                  >{labelFor(p, realProfiles)}</button>
                {/each}
              </div>
            </div>
          {/if}
          {#if cksProfiles.length}
            <div class="flex-1 border border-[#5a6280] rounded-md px-2 pt-1.5 pb-2 space-y-1.5">
              <div class="text-[10px] text-slate-500 uppercase tracking-widest text-center">Topic drills</div>
              <div class="flex gap-1.5">
                {#each cksProfiles.sort() as p}
                  <button
                    onclick={() => profile = p}
                    class="flex-1 py-1.5 rounded text-sm font-medium transition-colors {profile === p
                      ? 'bg-[#3b82f6] text-white'
                      : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
                  >{labelFor(p, cksProfiles)}</button>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      </div>

      <div>
        <div class="block text-xs text-slate-400 uppercase tracking-wider mb-1.5">Duration</div>
        <div class="flex gap-2">
          {#each [{label:'2h', val:7200},{label:'1h', val:3600},{label:'30m', val:1800}] as opt}
            <button
              onclick={() => duration = opt.val}
              class="flex-1 py-2 rounded text-sm font-medium transition-colors {duration === opt.val
                ? 'bg-[#3b82f6] text-white'
                : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
            >{opt.label}</button>
          {/each}
        </div>
      </div>

      <div>
        <div class="block text-xs text-slate-400 uppercase tracking-wider mb-1.5">Mode</div>
        <div class="flex gap-2">
          <button onclick={() => examMode = true}
            class="flex-1 py-2 rounded text-sm font-medium transition-colors {examMode ? 'bg-[#3b82f6] text-white' : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
          >Real exam</button>
          <button onclick={() => examMode = false}
            class="flex-1 py-2 rounded text-sm font-medium transition-colors {!examMode ? 'bg-[#3b82f6] text-white' : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
          >Practice</button>
        </div>
        <p class="text-[11px] text-slate-500 mt-1.5 leading-snug">
          {examMode
            ? 'Like the real CKS: tasks are ready at start, no hints, no guide, no checks. Graded after End Exam.'
            : 'Setup Env, Check Answer with partial points, hints and the guide.'}
        </p>
      </div>

      <button
        onclick={startExam}
        class="w-full py-2.5 bg-[#3b82f6] hover:bg-[#2563eb] text-white font-semibold rounded transition-colors"
      >Start Exam</button>
    </div>

    <p class="text-slate-500 text-xs">
      Open the <a href="/terminal/" target="_blank" class="text-slate-400 hover:text-slate-300 underline">terminal</a>
      or the <a href="/desktop/vnc.html?autoconnect=true&resize=scale&reconnect=true&path=desktop/websockify" target="_blank" class="text-slate-400 hover:text-slate-300 underline">desktop</a>
      before starting.
    </p>
  </div>

<!-- ── Exam ────────────────────────────────────────────────────────────── -->
{:else if view === 'exam'}
  <div class="h-screen flex flex-col" style="height: 100dvh">

    <!-- Header -->
    <div class="flex-none bg-[#454c63] border-b border-[#5a6280] px-4 py-2 flex items-center gap-3">
      <img src="/logo.svg" alt="K16S" class="h-5 shrink-0" />
      <span class="text-slate-500 text-sm shrink-0 hidden sm:block">{session?.profile ? examLabel(session.profile) : ''}</span>

      <!-- Question nav pills -->
      <div class="flex gap-1 flex-wrap flex-1 min-w-0 overflow-hidden">
        {#each questions as q, i}
          <button
            onclick={() => selectQuestion(i)}
            class="w-7 h-7 rounded text-xs font-mono font-medium transition-all ring-1 {statusClass(q)}
                   {i === currentIdx ? 'ring-2 ring-white/50 scale-110' : 'ring-transparent'}"
            title={unavailableInThisMode(q) ? q.title + ' — unavailable in lightweight mode' : (flagged[q.id] ? 'Flagged: ' : '') + q.title}
          >{i + 1}</button>
        {/each}
      </div>

      <!-- Timer -->
      <span class="font-mono text-sm shrink-0 {timeClass}" title="Time remaining">{fmt(timeLeft)}</span>

      <button
        onclick={endExam}
        class="shrink-0 px-3 py-1 bg-red-900/60 hover:bg-red-800 text-red-300 text-xs rounded border border-red-800 transition-colors"
      >End Exam</button>
    </div>

    <!-- Body: question panel + terminal -->
    <div class="flex-1 flex overflow-hidden">

      <!-- Question Panel -->
      <div style="width: {leftPct}%" class="min-w-48 flex flex-col overflow-hidden">
        {#if currentQuestion}
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <div class="flex items-start justify-between gap-2">
              <div>
                <div class="text-xs text-slate-400 uppercase tracking-wide mb-0.5">
                  Task {currentIdx + 1} of {questions.length}
                </div>
                <h2 class="text-base font-semibold text-[#eef0f5]">{currentQuestion.title}</h2>
              </div>
              <span class="shrink-0 text-xs bg-[#4a5169] text-slate-300 px-2 py-1 rounded font-mono" title="{currentQuestion.weight} points">
                Weight {weightPct(currentQuestion)}%
              </span>
            </div>

            {#if currentQuestion.context}
              <div role="presentation" onclick={copyClick} class="rounded border border-[#3b82f6]/60 bg-[#1e3a8a]/30 p-2.5 text-xs text-slate-300 [&_code]:cursor-pointer">
                Solve this task on: <code class="bg-[#2a2f42] px-1 rounded text-slate-100">{currentQuestion.context}</code>
              </div>
            {/if}

            {#if isExam}
              {@const st = progress[currentQuestion.id]?.status}
              {#if !st || st === 'preparing'}
                <div class="rounded border border-slate-600 bg-slate-800/40 p-2.5 text-xs text-slate-400">
                  The environment for this task is being prepared. You can read the task now.
                </div>
              {:else if st === 'setup-failed'}
                <div class="rounded border border-red-900 bg-red-950/30 p-2.5 text-xs text-red-300">
                  Setup of this task failed. Skip it, or end the exam and use Practice mode for this task.
                </div>
              {/if}
            {/if}

            {#if currentUnavailable}
              <div class="rounded border border-amber-800 bg-amber-950/30 p-3">
                <div class="text-xs font-semibold mb-1 text-amber-400">Unavailable in lightweight mode</div>
                <p class="text-xs text-amber-200/80 leading-relaxed">
                  This task's environment can't be created in this lightweight (kind) installation — it needs
                  the full VM-based install (kubeadm + Incus or Lima). Switch install modes to attempt it.
                </p>
              </div>
            {/if}

            <div role="presentation" onclick={copyClick} class="[&_code]:cursor-pointer [&_code:hover]:ring-1 [&_code:hover]:ring-[#3b82f6] text-sm text-slate-300 leading-relaxed space-y-1 [&_ul]:list-disc [&_ul]:pl-5 [&_li]:my-0.5 [&_p]:my-1 [&_strong]:text-slate-200">
              {@html md(currentQuestion.description)}
            </div>

            {#if currentQuestion.hint && !isExam}
              <details class="group">
                <summary class="cursor-pointer text-xs text-[#3b82f6] hover:text-blue-300 select-none">
                  Show hint
                </summary>
                <div class="mt-2 text-xs text-slate-400 bg-[#3b4256] border border-[#5a6280] rounded p-3 leading-relaxed">
                  {currentQuestion.hint}
                </div>
              </details>
            {/if}

            {#if copiedMsg}
              <div class="fixed bottom-20 left-6 z-50 text-xs bg-green-900 text-green-100 border border-green-700 rounded px-3 py-2">{copiedMsg}. Paste in the desktop: Ctrl+Shift+V</div>
            {/if}

            <!-- CKS hub: per-task scaffold guide from 07-scaffolds.md -->
            {#if !isExam && guideFor(currentQuestion.id).length}
              {#key currentQuestion.id}
                <details class="group">
                  <summary class="cursor-pointer text-xs text-amber-400 hover:text-amber-300 select-none">
                    Show guide (where to copy from)
                  </summary>
                  <div role="presentation" onclick={copyClick} class="mt-2 space-y-3 [&_code]:cursor-pointer [&_pre]:cursor-pointer [&_code:hover]:ring-1 [&_code:hover]:ring-[#3b82f6]">
                    {#each guideFor(currentQuestion.id) as g}
                      <div class="text-xs text-slate-400 bg-[#3b4256] border border-[#5a6280] rounded p-3 leading-relaxed">
                        <div class="text-amber-300 font-semibold mb-1">{g.num} {g.title}</div>
                        {@html renderGuide(g.body)}
                      </div>
                    {/each}
                    {#if manifestsFor(currentQuestion.id).length}
                      <div class="text-xs text-slate-400 bg-[#3b4256] border border-[#5a6280] rounded p-3 leading-relaxed">
                        <div class="text-amber-300 font-semibold mb-1">Full manifests (kubernetes.io examples). Click a block to copy it.</div>
                        {#each manifestsFor(currentQuestion.id) as m}
                          <div class="mt-3 mb-1 text-slate-300">{m.name}</div>
                          <pre class="bg-[#161922] text-slate-200 p-2 rounded overflow-x-auto text-[11px] leading-snug">{m.code}</pre>
                        {/each}
                      </div>
                    {/if}
                  </div>
                </details>
              {/key}
            {/if}

            {#if checkResult}
              <div class="rounded border {checkResult.unavailable
                ? 'border-amber-800 bg-amber-950/30'
                : checkResult.passed
                  ? 'border-green-800 bg-green-950/40'
                  : 'border-red-900 bg-red-950/30'} p-3">
                <div class="text-xs font-semibold mb-1 {checkResult.unavailable
                  ? 'text-amber-400'
                  : checkResult.passed ? 'text-green-400' : 'text-red-400'}">
                  {#if checkResult.unavailable}
                    Unavailable in this mode
                  {:else if checkResult.isSetup}
                    {checkResult.passed ? 'Environment ready' : 'Setup failed'}
                  {:else if checkResult.checks_total}
                    {checkResult.passed ? 'PASSED' : checkResult.checks_passed > 0 ? 'PARTIAL' : 'FAILED'}
                    · {checkResult.checks_passed}/{checkResult.checks_total} checks
                    · {(Math.round((currentQuestion.weight * checkResult.checks_passed / checkResult.checks_total) * 10) / 10)} of {currentQuestion.weight} pts
                  {:else}
                    {checkResult.passed ? 'PASSED' : 'FAILED'}
                  {/if}
                </div>
                {#if checkResult.output}
                  <pre class="text-xs text-slate-400 whitespace-pre-wrap !bg-transparent !border-0 !p-0">{checkResult.output}</pre>
                {/if}
              </div>
            {/if}
          </div>

          <!-- Action bar -->
          <div class="flex-none border-t border-[#5a6280] p-3 flex gap-2">
            {#if isExam}
            <button
              onclick={() => toggleFlag(currentQuestion)}
              class="flex-1 py-1.5 text-xs rounded border transition-colors {flagged[currentQuestion.id] ? 'border-amber-500 text-amber-300 bg-amber-900/30' : 'border-[#5a6280] text-slate-400 hover:text-slate-200'}"
            >{flagged[currentQuestion.id] ? 'Flagged for review' : 'Flag for review'}</button>
            <button
              onclick={() => selectQuestion(Math.min(currentIdx + 1, questions.length - 1))}
              disabled={currentIdx >= questions.length - 1}
              class="flex-1 py-1.5 text-xs rounded bg-[#3b82f6] hover:bg-[#2563eb] text-white font-medium transition-colors disabled:opacity-50"
            >Next task</button>
            {:else}
            <button
              onclick={setupEnv}
              disabled={setting_up || currentUnavailable}
              class="flex-1 py-1.5 text-xs rounded border border-[#5a6280] text-slate-400 hover:text-slate-200 hover:border-slate-500 transition-colors disabled:opacity-50"
            >{setting_up ? 'Setting up…' : 'Setup Env'}</button>
            <button
              onclick={checkAnswer}
              disabled={checking || currentUnavailable}
              class="flex-1 py-1.5 text-xs rounded bg-[#3b82f6] hover:bg-[#2563eb] text-white font-medium transition-colors disabled:opacity-50"
            >{checking ? 'Checking…' : 'Check Answer'}</button>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Terminal / Desktop -->
      <!-- CKS hub: drag to resize, double-click to reset -->
      <div role="separator" aria-orientation="vertical" tabindex="-1"
        onpointerdown={startDrag} ondblclick={() => (leftPct = 25)}
        class="w-1.5 shrink-0 cursor-col-resize bg-[#5a6280] hover:bg-[#3b82f6] {dragging ? 'bg-[#3b82f6]' : ''}"></div>
      <div class="flex-1 flex flex-col overflow-hidden">
        <div class="flex-none flex gap-1 bg-[#454c63] border-b border-[#5a6280] px-2 py-1.5">
          <button
            onclick={() => selectPanel('terminal')}
            class="px-3 py-1 rounded text-xs font-medium transition-colors {rightPanel === 'terminal'
              ? 'bg-[#3b82f6] text-white'
              : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
          >Terminal</button>
          <button
            onclick={() => selectPanel('desktop')}
            class="px-3 py-1 rounded text-xs font-medium transition-colors {rightPanel === 'desktop'
              ? 'bg-[#3b82f6] text-white'
              : 'bg-[#4a5169] text-slate-400 hover:text-slate-200'}"
          >Desktop</button>
        </div>

        <div class="flex-1 relative {dragging ? 'pointer-events-none' : ''}">
          <iframe
            bind:this={terminalIframe}
            src="/terminal/"
            title="Terminal"
            class="absolute inset-0 w-full h-full border-0"
            style={rightPanel === 'terminal' ? '' : 'display:none'}
            onload={() => {
              const win = terminalIframe?.contentWindow;
              if (!win) return;
              win.focus();
              win.document.addEventListener('keydown', (e) => {
                if (e.ctrlKey && e.shiftKey && e.key.toUpperCase() === 'C') {
                  e.preventDefault();
                  e.stopPropagation();
                  const text = win.term?.getSelection?.();
                  if (text) navigator.clipboard.writeText(text).catch(() => {});
                }
              }, true);
            }}
          ></iframe>

          {#if desktopLoaded}
            <iframe
              src="/desktop/vnc.html?autoconnect=true&resize=remote&reconnect=true&path=desktop/websockify"
              title="Desktop"
              class="absolute inset-0 w-full h-full border-0"
              style={rightPanel === 'desktop' ? '' : 'display:none'}
            ></iframe>
          {/if}
        </div>
      </div>

    </div>
  </div>

<!-- ── Results ─────────────────────────────────────────────────────────── -->
{:else if view === 'results'}
  <div class="h-screen flex flex-col items-center justify-start overflow-y-auto py-12 px-4 gap-8">
    {#if !session?.graded_at}
      <div class="text-center space-y-2">
        <div class="text-slate-200 text-lg">Grading all tasks…</div>
        <div class="text-slate-500 text-sm">Like the real exam, every task is checked after the end. This takes a minute or two.</div>
      </div>
    {:else}
    {@const pct = Math.round((score / (totalPoints || 1)) * 100)}
    <div class="text-center">
      <div class="text-4xl font-bold text-white mb-1">
        <span class="{pct >= 67 ? 'text-green-400' : 'text-red-400'}">{pct}%</span>
      </div>
      <div class="text-slate-300 text-sm mb-1">{pct >= 67 ? 'PASS' : 'FAIL'} (pass mark 67%) · {score} of {totalPoints} points</div>
      <div class="text-slate-500 text-xs">
        {session?.profile ? examLabel(session.profile) : ''} · {session?.exam_mode ? 'Real exam mode' : 'Practice mode'}
      </div>
    </div>
    {/if}

    <div class="w-full max-w-lg space-y-2">
      {#each questions as q, i}
        {@const p = progress[q.id]}
        {@const unavailable = unavailableInThisMode(q)}
        <div class="flex items-start gap-3 bg-[#3b4256] border border-[#5a6280] rounded p-3 {unavailable ? 'opacity-60' : ''}">
          <div class="w-6 h-6 rounded flex items-center justify-center text-xs font-mono shrink-0 mt-0.5
            {unavailable ? 'bg-[#4a5169] text-slate-600' :
             p?.status === 'passed' ? 'bg-green-700 text-green-100' :
             p?.status === 'partial' ? 'bg-yellow-700 text-yellow-100' :
             p?.status === 'failed' ? 'bg-red-800 text-red-100' :
             'bg-[#4a5169] text-slate-400'}"
          >{i + 1}</div>
          <div class="flex-1 min-w-0">
            <div class="text-sm text-slate-300">{q.title}</div>
            <div class="text-xs text-slate-500 mt-0.5">
              {unavailable ? 'Unavailable in lightweight mode — excluded from scoring' : `Weight ${weightPct(q)}%` + (p?.checks_total ? ` · ${p.checks_passed}/${p.checks_total} checks` : '')}
            </div>
            {#if p?.output && p.status !== 'passed' && session?.graded_at}
              <details class="mt-1">
                <summary class="text-xs text-slate-400 cursor-pointer">What failed</summary>
                <pre class="text-[11px] text-slate-400 whitespace-pre-wrap mt-1">{p.output}</pre>
              </details>
            {/if}
          </div>
          <div class="text-xs font-medium shrink-0 mt-0.5
            {unavailable ? 'text-slate-600' :
             p?.status === 'passed' ? 'text-green-400' :
             p?.status === 'failed' ? 'text-red-400' :
             'text-slate-500'}"
          >
            {unavailable ? 'N/A' : p?.checks_total || p?.status === 'passed' ? (Math.round(pointsFor(q) * 10) / 10) + ' / ' + q.weight : '—'}
          </div>
        </div>
      {/each}
    </div>

    <button
      onclick={newExam}
      class="px-6 py-2.5 bg-[#3b82f6] hover:bg-[#2563eb] text-white font-semibold rounded transition-colors"
    >New Exam</button>
  </div>
{/if}

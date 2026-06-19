const API = 'http://localhost:8000';

// ─── State ────────────────────────────────────────────────────────────────────
let currentTab = 'home';
let isRecording = false;
let recordSeconds = 0;
let recordInterval = null;
let mediaRecorder = null;
let audioChunks = [];
let currentMeetingId = null;
let audioDeleted = false;

// ─── DOM refs ─────────────────────────────────────────────────────────────────
const screens = {
  login:      document.getElementById('login-screen'),
  signup:     document.getElementById('signup-screen'),
  home:       document.getElementById('home-screen'),
  record:     document.getElementById('record-screen'),
  search:     document.getElementById('search-screen'),
  settings:   document.getElementById('settings-screen'),
  detail:     document.getElementById('detail-screen'),
  processing: document.getElementById('processing-screen'),
  result:     document.getElementById('result-screen'),
};
const bottomNav = document.getElementById('bottom-nav');
const snackbar  = document.getElementById('snackbar');

// ─── Navigation ───────────────────────────────────────────────────────────────
function showScreen(name) {
  Object.values(screens).forEach(el => el?.classList.remove('active'));
  screens[name]?.classList.add('active');
  const mainScreens = ['home', 'record', 'search', 'settings'];
  bottomNav.classList.toggle('hidden', !mainScreens.includes(name));
}

function showTab(tab) {
  currentTab = tab;
  showScreen(tab);
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
}

function showSnackbar(msg) {
  snackbar.textContent = msg;
  snackbar.classList.add('show');
  setTimeout(() => snackbar.classList.remove('show'), 3000);
}

// ─── Auth (UI only) ───────────────────────────────────────────────────────────
document.getElementById('login-form').addEventListener('submit', e => {
  e.preventDefault();
  const email    = document.getElementById('login-email');
  const password = document.getElementById('login-password');
  document.getElementById('email-error').classList.toggle('show', !email.value.trim());
  document.getElementById('password-error').classList.toggle('show', !password.value);
  if (!email.value.trim() || !password.value) return;
  const btn = document.getElementById('login-btn');
  btn.disabled = true; btn.textContent = 'Loading...';
  setTimeout(() => { btn.disabled = false; btn.textContent = 'Login'; showTab('home'); }, 600);
});

document.getElementById('toggle-password').addEventListener('click', () => {
  const i = document.getElementById('login-password');
  i.type = i.type === 'password' ? 'text' : 'password';
});

document.getElementById('go-signup').addEventListener('click', () => showScreen('signup'));
document.getElementById('signup-back').addEventListener('click', () => showScreen('login'));
document.getElementById('signup-form').addEventListener('submit', e => {
  e.preventDefault();
  showScreen('login');
  showSnackbar('Account created. Please sign in.');
});

// ─── Home ─────────────────────────────────────────────────────────────────────
document.getElementById('home-search').addEventListener('click', () => showTab('search'));
document.getElementById('new-meeting-btn').addEventListener('click', () => showTab('record'));

// ─── Processing steps UI ─────────────────────────────────────────────────────
const STEPS = ['transcribing', 'translating', 'generating', 'done'];

function setStep(stepName) {
  STEPS.forEach(s => {
    const row  = document.getElementById(`step-${s}`);
    const icon = row.querySelector('.step-icon');
    const idx  = STEPS.indexOf(s);
    const cur  = STEPS.indexOf(stepName);
    if (idx < cur)       { icon.textContent = '✓'; icon.className = 'step-icon done'; }
    else if (idx === cur){ icon.textContent = '⟳'; icon.className = 'step-icon active'; }
    else                 { icon.textContent = '○'; icon.className = 'step-icon pending'; }
  });
}

function showProcessingError(msg) {
  document.getElementById('spinner')?.remove();
  const errEl    = document.getElementById('processing-error');
  const cancelEl = document.getElementById('processing-cancel');
  errEl.textContent = msg;
  errEl.style.display = 'block';
  cancelEl.style.display = 'block';
}

document.getElementById('processing-cancel').addEventListener('click', () => showTab('record'));

// ─── API helpers ──────────────────────────────────────────────────────────────
async function apiPost(path, body) {
  const opts = { method: 'POST' };
  if (body instanceof FormData) {
    opts.body = body;
  } else if (body) {
    opts.headers = { 'Content-Type': 'application/json' };
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(`${API}${path}`, opts);
  if (!res.ok) throw new Error(`${path} → ${res.status} ${await res.text()}`);
  return res.json();
}

async function apiGet(path) {
  const res = await fetch(`${API}${path}`);
  if (!res.ok) throw new Error(`${path} → ${res.status}`);
  return res.json();
}

async function apiDelete(path) {
  const res = await fetch(`${API}${path}`, { method: 'DELETE' });
  if (!res.ok) throw new Error(`DELETE ${path} → ${res.status}`);
  return res.json();
}

async function pollTranscription(meetingId) {
  for (let i = 0; i < 120; i++) {
    await new Promise(r => setTimeout(r, 3000));
    const data = await apiGet(`/transcription/${meetingId}`);
    if (data.status === 'done')   return data;
    if (data.status === 'failed') throw new Error('Transcription failed on server.');
  }
  throw new Error('Transcription timed out.');
}

// ─── Full pipeline ────────────────────────────────────────────────────────────
async function runPipeline(blob) {
  showScreen('processing');
  setStep('transcribing');
  document.getElementById('processing-error').style.display = 'none';
  document.getElementById('processing-cancel').style.display = 'none';
  audioDeleted = false;

  try {
    // 1 — Upload
    const formData = new FormData();
    formData.append('file', blob, 'recording.webm');
    const uploadData = await apiPost('/transcription/upload', formData);
    currentMeetingId = uploadData.meeting_id;

    // 2 — Poll transcription
    const transcriptData = await pollTranscription(currentMeetingId);

    // 3 — Translate
    setStep('translating');
    await apiPost(`/translation/${currentMeetingId}`, null);

    // 4 — Generate MoM
    setStep('generating');
    const summaryData = await apiPost(`/summary/${currentMeetingId}`, { type: 'meeting' });

    setStep('done');
    await new Promise(r => setTimeout(r, 500));

    showMomResult({
      meetingId: currentMeetingId,
      language:  transcriptData.language || 'unknown',
      transcript: transcriptData.transcript || '',
      summary:   summaryData.summary || '',
    });

  } catch (err) {
    showProcessingError(err.message || 'Something went wrong.');
  }
}

// ─── MoM result screen ────────────────────────────────────────────────────────
function showMomResult({ meetingId, language, transcript, summary }) {
  const container = document.getElementById('result-content');
  container.innerHTML = `
    <div class="result-meta-card">
      <span>🎙</span>
      <div>
        <div style="font-weight:600;font-size:14px;">${new Date().toLocaleDateString('en-US',{year:'numeric',month:'short',day:'numeric'})}</div>
        <div style="font-size:13px;color:var(--secondary-gray);">Language: ${language}</div>
      </div>
    </div>

    ${transcript ? `
    <div class="result-section-label">ORIGINAL TRANSCRIPT</div>
    <div class="result-block">${escHtml(transcript)}</div>
    ` : ''}

    <div class="result-section-label">MINUTES OF MEETING</div>
    <div class="result-block" style="white-space:pre-wrap;">${escHtml(summary)}</div>

    <div id="delete-audio-wrap" style="margin-top:24px;">
      <button class="logout-btn" id="delete-audio-btn" style="color:#ff3b30;border-color:#ff3b30;">
        🗑 Delete Audio Recording
      </button>
    </div>
  `;

  document.getElementById('delete-audio-btn').addEventListener('click', async () => {
    if (!confirm('Delete the audio file from the server? Your transcript and MoM will be kept.')) return;
    try {
      await apiDelete(`/transcription/${meetingId}/audio`);
      document.getElementById('delete-audio-wrap').innerHTML =
        '<p style="color:#34c759;font-size:14px;text-align:center;">✓ Audio deleted</p>';
      showSnackbar('Audio file deleted.');
    } catch (e) {
      showSnackbar('Failed to delete audio.');
    }
  });

  showScreen('result');
}

function escHtml(str) {
  return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

document.getElementById('result-back').addEventListener('click', () => showTab('home'));

document.getElementById('copy-mom-btn').addEventListener('click', () => {
  const block = document.querySelector('#result-content .result-block:last-of-type');
  if (block) {
    navigator.clipboard.writeText(block.textContent.trim());
    showSnackbar('Copied to clipboard.');
  }
});

// ─── Recording ────────────────────────────────────────────────────────────────
const timerEl  = document.getElementById('record-timer');
const statusEl = document.getElementById('record-status');
const micBtn   = document.getElementById('mic-btn');
const micHint  = document.getElementById('mic-hint');

function formatTime(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = String(Math.floor((seconds % 3600) / 60)).padStart(2, '0');
  const s = String(seconds % 60).padStart(2, '0');
  return h > 0 ? `${h}:${m}:${s}` : `${m}:${s}`;
}

micBtn.addEventListener('click', async () => {
  if (!isRecording) {
    // Start
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      audioChunks = [];
      mediaRecorder = new MediaRecorder(stream);
      mediaRecorder.ondataavailable = e => { if (e.data.size > 0) audioChunks.push(e.data); };
      mediaRecorder.onstop = () => {
        stream.getTracks().forEach(t => t.stop());
        const blob = new Blob(audioChunks, { type: 'audio/webm' });
        runPipeline(blob);
      };
      mediaRecorder.start();
      isRecording = true;
      recordSeconds = 0;
      micBtn.classList.add('recording');
      micBtn.textContent = '■';
      statusEl.textContent = 'Recording... (all languages supported)';
      micHint.textContent  = 'Tap to stop & process';
      recordInterval = setInterval(() => {
        recordSeconds++;
        timerEl.textContent = formatTime(recordSeconds);
      }, 1000);
    } catch (err) {
      showSnackbar('Microphone access denied.');
    }
  } else {
    // Stop
    isRecording = false;
    clearInterval(recordInterval);
    micBtn.classList.remove('recording');
    micBtn.textContent   = '🎤';
    statusEl.textContent = 'Processing...';
    micHint.textContent  = 'Please wait';
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.stop();
    }
  }
});

// ─── Search (static demo) ─────────────────────────────────────────────────────
const SEARCH_RESULTS = [
  { title:'Q3 Product Planning', snippet:'...aligned on Q3 priorities...', date:'Today', duration:'42 min', matchType:'Summary' },
  { title:'Client Discovery Call', snippet:'...enterprise transcription accuracy...', date:'Yesterday', duration:'28 min', matchType:'Transcript' },
  { title:'Weekly Team Sync', snippet:'...cross-team sync needed...', date:'Mon', duration:'35 min', matchType:'Insight' },
];

const searchInput = document.getElementById('search-input');
const clearSearch = document.getElementById('clear-search');
const resultsList = document.getElementById('search-results');

function renderResults(results) {
  resultsList.innerHTML = results.length
    ? results.map(r => `
        <div class="result-item">
          <h3>${r.title}</h3>
          <p>${r.snippet}</p>
          <div class="result-meta">${r.date} · ${r.duration} · ${r.matchType}</div>
        </div>`).join('')
    : '<p style="color:var(--secondary-gray);padding:16px 0;">No results found</p>';
}

searchInput.addEventListener('input', () => {
  clearSearch.classList.toggle('show', searchInput.value.length > 0);
  const q = searchInput.value.trim().toLowerCase();
  renderResults(q ? SEARCH_RESULTS.filter(r =>
    r.title.toLowerCase().includes(q) || r.snippet.toLowerCase().includes(q)
  ) : SEARCH_RESULTS);
});

clearSearch.addEventListener('click', () => {
  searchInput.value = '';
  clearSearch.classList.remove('show');
  renderResults(SEARCH_RESULTS);
});

// ─── Detail screen (legacy static MoM) ───────────────────────────────────────
document.getElementById('detail-back')?.addEventListener('click', () => showTab('search'));
document.getElementById('delete-mom-btn')?.addEventListener('click', () => {
  if (confirm('Delete this meeting record?')) showTab('search');
});

// ─── Settings ─────────────────────────────────────────────────────────────────
document.getElementById('logout-btn').addEventListener('click', () => {
  isRecording = false;
  recordSeconds = 0;
  clearInterval(recordInterval);
  if (mediaRecorder && mediaRecorder.state !== 'inactive') mediaRecorder.stop();
  timerEl.textContent = '00:00';
  statusEl.textContent = 'Ready to record';
  micHint.textContent  = 'Tap to start';
  micBtn.classList.remove('recording');
  micBtn.textContent = '🎤';
  showScreen('login');
});

// ─── Bottom nav ───────────────────────────────────────────────────────────────
document.querySelectorAll('.nav-item').forEach(btn => {
  btn.addEventListener('click', () => showTab(btn.dataset.tab));
});

// ─── Init ─────────────────────────────────────────────────────────────────────
showScreen('login');
renderResults(SEARCH_RESULTS);

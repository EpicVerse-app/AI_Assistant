// Search data (from Flutter search_data.dart)
const SEARCH_RESULTS = [
  {
    title: 'Q3 Product Planning',
    snippet: '...aligned on Q3 priorities, reviewed the product roadmap, and identified three critical milestones...',
    date: 'Today',
    duration: '42 min',
    category: 'Meetings',
    matchType: 'Summary',
  },
  {
    title: 'Client Discovery Call',
    snippet: '...discussed enterprise requirements and transcription accuracy targets for the AI memory platform...',
    date: 'Yesterday',
    duration: '28 min',
    category: 'Calls',
    matchType: 'Transcript',
  },
  {
    title: 'Weekly Team Sync',
    snippet: '...cross-team sync needed between design and engineering for the memory detail experience...',
    date: 'Mon',
    duration: '35 min',
    category: 'Meetings',
    matchType: 'Insight',
  },
  {
    title: 'Brainstorm Session',
    snippet: '...three new ideas captured around real-time transcription and smart search filters...',
    date: 'Sun',
    duration: '18 min',
    category: 'Ideas',
    matchType: 'Action Item',
  },
  {
    title: 'Investor Update Prep',
    snippet: '...prepared talking points on AI summarization beta launch and customer feedback loops...',
    date: 'Last week',
    duration: '22 min',
    category: 'Meetings',
    matchType: 'Summary',
  },
];

const MOM_SAMPLE = {
  attendees: ['Alex', 'Sarah', 'Mike', 'Priya'],
  summary: 'The team aligned on Q3 priorities, reviewed the product roadmap, and identified three critical milestones. Discussion focused on accelerating AI memory features while maintaining transcription accuracy.',
  decisions: [
    'Prioritize AI summarization for Q3 launch',
    'Raise transcription accuracy target to 98%',
    'Run weekly customer feedback sessions',
  ],
  actionItems: [
    'Schedule design review for memory detail screen',
    'Share updated roadmap with stakeholders',
    'Draft technical spec for real-time transcription',
    'Set up weekly customer feedback sessions',
  ],
  deadlines: [
    'Share roadmap with stakeholders — Friday',
    'Technical spec draft — Next Wednesday',
    'Design review — Next Monday',
    'Weekly feedback sessions — Start next week',
  ],
  importantNotes: [
    'Enterprise customers need higher transcription accuracy',
    'Cross-team sync required between design and engineering',
    'Beta launch target: end of Q3',
  ],
};

// State
let currentTab = 'home';
let isRecording = false;
let recordSeconds = 0;
let recordInterval = null;
let currentMemory = null;

// DOM
const screens = {
  login: document.getElementById('login-screen'),
  signup: document.getElementById('signup-screen'),
  home: document.getElementById('home-screen'),
  record: document.getElementById('record-screen'),
  search: document.getElementById('search-screen'),
  settings: document.getElementById('settings-screen'),
  detail: document.getElementById('detail-screen'),
};

const bottomNav = document.getElementById('bottom-nav');
const snackbar = document.getElementById('snackbar');

function showScreen(name) {
  Object.values(screens).forEach((el) => el?.classList.remove('active'));
  screens[name]?.classList.add('active');

  const mainScreens = ['home', 'record', 'search', 'settings'];
  bottomNav.classList.toggle('hidden', !mainScreens.includes(name));
}

function showTab(tab) {
  currentTab = tab;
  showScreen(tab);
  document.querySelectorAll('.nav-item').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
}

function showSnackbar(message) {
  snackbar.textContent = message;
  snackbar.classList.add('show');
  setTimeout(() => snackbar.classList.remove('show'), 2500);
}

// Login
document.getElementById('login-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const email = document.getElementById('login-email');
  const password = document.getElementById('login-password');
  let valid = true;

  document.getElementById('email-error').classList.toggle('show', !email.value.trim());
  document.getElementById('password-error').classList.toggle('show', !password.value);
  valid = email.value.trim() && password.value;

  if (!valid) return;

  const btn = document.getElementById('login-btn');
  btn.disabled = true;
  btn.textContent = 'Loading...';

  setTimeout(() => {
    btn.disabled = false;
    btn.textContent = 'Login';
    showTab('home');
  }, 600);
});

document.getElementById('toggle-password').addEventListener('click', () => {
  const input = document.getElementById('login-password');
  input.type = input.type === 'password' ? 'text' : 'password';
});

document.getElementById('go-signup').addEventListener('click', () => showScreen('signup'));
document.getElementById('signup-back').addEventListener('click', () => showScreen('login'));

document.getElementById('signup-form').addEventListener('submit', (e) => {
  e.preventDefault();
  showScreen('login');
  showSnackbar('Account created. Please sign in.');
});

// Home
document.getElementById('home-search').addEventListener('click', () => showTab('search'));
document.getElementById('new-meeting-btn').addEventListener('click', () => showTab('record'));

// Record
const timerEl = document.getElementById('record-timer');
const statusEl = document.getElementById('record-status');
const micBtn = document.getElementById('mic-btn');
const micHint = document.getElementById('mic-hint');

function formatTime(seconds) {
  const m = String(Math.floor(seconds / 60)).padStart(2, '0');
  const s = String(seconds % 60).padStart(2, '0');
  return `${m}:${s}`;
}

micBtn.addEventListener('click', () => {
  isRecording = !isRecording;
  micBtn.classList.toggle('recording', isRecording);
  micBtn.textContent = isRecording ? '■' : '🎤';

  if (isRecording) {
    statusEl.textContent = 'Recording...';
    micHint.textContent = 'Tap to stop';
    recordInterval = setInterval(() => {
      recordSeconds += 1;
      timerEl.textContent = formatTime(recordSeconds);
    }, 1000);
  } else {
    statusEl.textContent = 'Ready to record';
    micHint.textContent = 'Tap to start';
    clearInterval(recordInterval);
  }
});

// Search
const searchInput = document.getElementById('search-input');
const clearSearch = document.getElementById('clear-search');
const resultsList = document.getElementById('search-results');

function filterResults(query) {
  const q = query.trim().toLowerCase();
  if (!q) return SEARCH_RESULTS;
  return SEARCH_RESULTS.filter(
    (r) =>
      r.title.toLowerCase().includes(q) ||
      r.snippet.toLowerCase().includes(q) ||
      r.category.toLowerCase().includes(q) ||
      r.matchType.toLowerCase().includes(q)
  );
}

function renderResults(results) {
  resultsList.innerHTML = results.length
    ? results
        .map(
          (r) => `
        <div class="result-item" data-title="${r.title}" data-duration="${r.duration}">
          <h3>${r.title}</h3>
          <p>${r.snippet}</p>
          <div class="result-meta">${r.date} · ${r.duration} · ${r.matchType}</div>
        </div>`
        )
        .join('')
    : '<p style="color:#86868b;padding:16px 0;">No results found</p>';

  document.querySelectorAll('.result-item').forEach((item) => {
    item.addEventListener('click', () => openMemoryDetail(item.dataset.title, item.dataset.duration));
  });
}

searchInput.addEventListener('input', () => {
  clearSearch.classList.toggle('show', searchInput.value.length > 0);
  renderResults(filterResults(searchInput.value));
});

clearSearch.addEventListener('click', () => {
  searchInput.value = '';
  clearSearch.classList.remove('show');
  renderResults(SEARCH_RESULTS);
});

function renderMomList(label, items) {
  return `
    <div class="mom-field">
      <h3>${label}</h3>
      <ul>${items.map((i) => `<li>${i}</li>`).join('')}</ul>
      <hr>
    </div>`;
}

function renderMomField(label, value) {
  return `
    <div class="mom-field">
      <h3>${label}</h3>
      <p>${value}</p>
      <hr>
    </div>`;
}

// MoM detail
function openMemoryDetail(title, duration) {
  currentMemory = { title, duration };
  const today = new Date().toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });

  document.getElementById('mom-fields').innerHTML =
    renderMomField('Meeting Date', today) +
    renderMomField('Meeting Topic', title) +
    renderMomField('Attendees', MOM_SAMPLE.attendees.join(', ')) +
    renderMomField('Summary', MOM_SAMPLE.summary) +
    renderMomList('Decisions', MOM_SAMPLE.decisions) +
    renderMomList('Action Items', MOM_SAMPLE.actionItems) +
    renderMomList('Deadlines', MOM_SAMPLE.deadlines) +
    renderMomList('Important Notes', MOM_SAMPLE.importantNotes);

  showScreen('detail');
}

document.getElementById('detail-back').addEventListener('click', () => showTab('search'));

document.getElementById('delete-mom-btn').addEventListener('click', () => {
  if (confirm('Delete this meeting record?')) showTab('search');
});

// Settings logout
document.getElementById('logout-btn').addEventListener('click', () => {
  isRecording = false;
  recordSeconds = 0;
  clearInterval(recordInterval);
  timerEl.textContent = '00:00';
  micBtn.classList.remove('recording');
  micBtn.textContent = '🎤';
  showScreen('login');
});

// Bottom nav
document.querySelectorAll('.nav-item').forEach((btn) => {
  btn.addEventListener('click', () => showTab(btn.dataset.tab));
});

// Init
showScreen('login');
renderResults(SEARCH_RESULTS);

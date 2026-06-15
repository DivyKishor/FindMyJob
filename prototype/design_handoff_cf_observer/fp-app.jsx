// fp-app.jsx — application shell: state, filtering, routing, tweaks, render.

(function () {
  const e = React.createElement;

  const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
    "accent": "#0e93de",
    "corners": "sharp"
  }/*EDITMODE-END*/;

  // luminance → pick ink or cream text on a given accent
  function onColorFor(hex) {
    const h = hex.replace('#', '');
    const r = parseInt(h.slice(0, 2), 16) / 255, g = parseInt(h.slice(2, 4), 16) / 255, b = parseInt(h.slice(4, 6), 16) / 255;
    const lin = (c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
    const L = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
    return L > 0.45 ? '#141412' : '#f3efe4';
  }

  const SAVE_KEY = 'fp-saved-roles';
  const APPLIED_KEY = 'fp-applied-roles';
  function loadSaved() {
    try { return new Set(JSON.parse(localStorage.getItem(SAVE_KEY) || '[]')); } catch { return new Set(); }
  }
  function loadApplied() {
    try { return new Set(JSON.parse(localStorage.getItem(APPLIED_KEY) || '[]')); } catch { return new Set(); }
  }

  function filterJobs(jobs, query, filters, sort) {
    const q = query.trim().toLowerCase();
    let r = jobs.filter((j) => {
      if (filters.companyId && j.companyId !== filters.companyId) return false;
      if (filters.work !== 'all' && j.work !== filters.work) return false;
      if (j.score < filters.minScore) return false;
      if (filters.eligible && j.score < 70) return false;
      if (q) {
        const hay = (j.title + ' ' + j.company + ' ' + j.loc + ' ' + j.stack.join(' ') + ' ' + j.summary).toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
    r = r.slice().sort((a, b) => sort === 'new' ? (a.postedDays - b.postedDays) || (b.score - a.score) : (b.score - a.score) || (a.postedDays - b.postedDays));
    return r;
  }

  function App() {
    const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
    const [view, setView] = React.useState('today');
    const [prevView, setPrevView] = React.useState('board');
    const [selId, setSelId] = React.useState(null);
    const [selCompany, setSelCompany] = React.useState(null);
    const [query, setQuery] = React.useState('');
    const [filters, setFilters] = React.useState({ work: 'all', minScore: 0, eligible: false, companyId: null });
    const [sort, setSort] = React.useState('score');
    const [saved, setSaved] = React.useState(loadSaved);
    const [applied, setApplied] = React.useState(loadApplied);
    const [applyTarget, setApplyTarget] = React.useState(null);
    const [loading, setLoading] = React.useState(false);
    const [toast, setToast] = React.useState('');
    const toastT = React.useRef(0);

    // apply theme vars
    React.useEffect(() => {
      const root = document.documentElement;
      root.style.setProperty('--fp-accent', t.accent);
      root.style.setProperty('--fp-accent-ink', onColorFor(t.accent));
      root.style.setProperty('--fp-radius', t.corners === 'soft' ? '12px' : '0px');
    }, [t.accent, t.corners]);

    React.useEffect(() => {
      try { localStorage.setItem(SAVE_KEY, JSON.stringify([...saved])); } catch {}
    }, [saved]);

    React.useEffect(() => {
      try { localStorage.setItem(APPLIED_KEY, JSON.stringify([...applied])); } catch {}
    }, [applied]);

    const showToast = (m) => {
      setToast(m); clearTimeout(toastT.current);
      toastT.current = setTimeout(() => setToast(''), 2600);
    };

    const jobById = React.useMemo(() => Object.fromEntries(JOBS.map((j) => [j.id, j])), []);
    const filtered = React.useMemo(() => filterJobs(JOBS, query, filters, sort), [query, filters, sort]);
    const briefingJobs = React.useMemo(() => JOBS.slice().sort((a, b) => b.score - a.score), []);
    const savedJobs = React.useMemo(() => JOBS.filter((j) => saved.has(j.id)).sort((a, b) => b.score - a.score), [saved]);

    const goBoard = () => { setLoading(true); setView('board'); setTimeout(() => setLoading(false), 480); };

    const nav = (v) => {
      if (v === 'board') return goBoard();
      window.scrollTo({ top: 0 });
      setView(v);
    };

    const openJob = (job) => { setPrevView(view === 'detail' ? prevView : view); setSelId(job.id); setView('detail'); window.scrollTo({ top: 0 }); };

    const toggleSave = (id) => {
      setSaved((s) => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); showToast(n.has(id) ? 'Saved to your list' : 'Removed from saved'); return n; });
    };

    const openCompany = (c) => { setSelCompany(c.id); setView('company'); window.scrollTo({ top: 0 }); };
    const viewCompanyRoles = (cid) => { setFilters((f) => ({ ...f, companyId: cid })); goBoard(); };
    const clearCompany = () => setFilters((f) => ({ ...f, companyId: null }));
    const onSearchGo = () => { if (view !== 'board') goBoard(); };
    const openApply = (job) => setApplyTarget(job);
    const submitApply = (id) => { setApplied((s) => new Set(s).add(id)); showToast('Application sent ✓'); };

    const sel = selId != null ? jobById[selId] : null;
    const related = sel ? JOBS.filter((j) => j.id !== sel.id && (j.companyId === sel.companyId || j.region === sel.region)).sort((a, b) => b.score - a.score).slice(0, 3) : [];
    const unread = ALERTS.filter((a) => !a.read).length;
    const activeCompanyName = filters.companyId ? (COMPANIES.find((c) => c.id === filters.companyId) || {}).name : null;

    let screen;
    if (view === 'today') screen = e(Briefing, { jobs: briefingJobs, saved, applied, onOpen: openJob, onToggleSave: toggleSave, onApply: openApply, onNav: nav });
    else if (view === 'board') screen = e(Board, { jobs: filtered, saved, applied, onOpen: openJob, onToggleSave: toggleSave, loading, filters, setFilters, sort, setSort, total: JOBS.length, activeCompany: activeCompanyName, onClearCompany: clearCompany });
    else if (view === 'detail' && sel) screen = e(JobDetail, { job: sel, saved: saved.has(sel.id), applied: applied.has(sel.id), appliedSet: applied, onToggleSave: toggleSave, onBack: () => nav(prevView), onOpen: openJob, onApply: openApply, onAlert: showToast, related });
    else if (view === 'companies') screen = e(Companies, { onOpenCompany: openCompany });
    else if (view === 'company' && selCompany) {
      const co = COMPANIES.find((c) => c.id === selCompany);
      const coJobs = JOBS.filter((j) => j.companyId === selCompany).sort((a, b) => b.score - a.score);
      screen = e(CompanyDetail, { company: co, jobs: coJobs, saved, applied, onOpen: openJob, onToggleSave: toggleSave, onBack: () => nav('companies'), onViewRoles: () => viewCompanyRoles(selCompany) });
    }
    else if (view === 'pipeline') screen = e(Pipeline, { onAlert: showToast });
    else if (view === 'network') screen = e(Network, { onAlert: showToast });
    else if (view === 'settings') screen = e(Settings, { onAlert: showToast });
    else if (view === 'alerts') screen = e(Alerts, { onOpen: openJob, jobById, onAlert: showToast });
    else if (view === 'saved') screen = e(Saved, { jobs: savedJobs, saved, applied, onOpen: openJob, onToggleSave: toggleSave, onNav: nav });
    else screen = e(Briefing, { jobs: briefingJobs, saved, applied, onOpen: openJob, onToggleSave: toggleSave, onApply: openApply, onNav: nav });

    return e('div', { className: 'fp-root' },
      e(TopNav, { view, onNav: nav, query, onQuery: setQuery, onSearchGo, savedCount: saved.size, unread }),
      e('div', { className: 'fp-screen', key: view + '/' + (selId || '') + '/' + (selCompany || '') }, screen),
      applyTarget && e(ApplyModal, { job: applyTarget, applied: applied.has(applyTarget.id), onClose: () => setApplyTarget(null), onSubmit: submitApply }),
      e(Toast, { msg: toast }),
      e(TweaksPanel, null,
        e(TweakSection, { label: 'Accent' }),
        e(TweakColor, { label: 'Accent color', value: t.accent, options: ['#0e93de', '#ccf23f', '#ff6a3d', '#7b5cff'], onChange: (v) => setTweak('accent', v) }),
        e(TweakSection, { label: 'Style' }),
        e(TweakRadio, { label: 'Corners', value: t.corners, options: ['sharp', 'soft'], onChange: (v) => setTweak('corners', v) }),
      ),
    );
  }

  ReactDOM.createRoot(document.getElementById('root')).render(e(App));
})();

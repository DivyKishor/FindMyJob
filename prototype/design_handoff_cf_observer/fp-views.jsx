// fp-views.jsx — all screens for the Frontpage prototype.
// Reads presentational pieces + data from window (globals). Exports view
// components + TopNav to window for the app shell to compose.

(function () {
  const e = React.createElement;

  // ───────────────────────── Top navigation ─────────────────────────
  function TopNav({ view, onNav, query, onQuery, onSearchGo, savedCount, unread }) {
    const mobile = useIsMobile(1080);
    const [menu, setMenu] = React.useState(false);
    const links = [['today', 'Today'], ['board', 'Board'], ['companies', 'Companies'], ['alerts', 'Alerts'], ['pipeline', 'Pipeline'], ['network', 'Network']];
    const NavLink = ({ id, label }) => (
      <button className={'fp-reset fp-link fp-kick' + (view === id ? ' fp-link--on' : '')}
        style={{ color: 'var(--fp-ink)', padding: '4px 0', position: 'relative' }} onClick={() => { onNav(id); setMenu(false); }}>
        {label}{id === 'alerts' && unread > 0 && <span style={{ position: 'absolute', top: -4, right: -12, width: 7, height: 7, borderRadius: '50%', background: 'var(--fp-accent2)', border: '1.5px solid var(--fp-ink)' }} />}
      </button>
    );

    return (
      <header style={{ position: 'sticky', top: 0, zIndex: 40, background: 'var(--fp-cream)', borderBottom: '2px solid var(--fp-ink)' }}>
        <div className="fp-wrap" style={{ display: 'flex', alignItems: 'center', gap: 18, height: 64 }}>
          <button className="fp-reset fp-disp" style={{ fontSize: 20 }} onClick={() => onNav('today')}>CF<span style={{ color: 'var(--fp-accent2)' }}>/</span>OBSERVER</button>

          {!mobile && (
            <nav style={{ display: 'flex', gap: 26, marginLeft: 10 }}>{links.map(([id, label]) => <NavLink key={id} id={id} label={label} />)}</nav>
          )}

          <div style={{ flex: 1 }} />

          {!mobile && (
            <div style={{ position: 'relative', width: 168 }}>
              <svg style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)' }} width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--fp-mute)" strokeWidth="2"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg>
              <input className="fp-in" style={{ paddingLeft: 34, padding: '10px 12px 10px 34px' }} placeholder="Search…"
                value={query} onChange={(ev) => onQuery(ev.target.value)}
                onKeyDown={(ev) => { if (ev.key === 'Enter') onSearchGo(); }} onFocus={() => view !== 'board' && onSearchGo()} />
            </div>
          )}

          <button className={'fp-reset fp-save' + (savedCount ? ' fp-save--on' : '')} onClick={() => onNav('saved')} title="Saved roles"
            style={{ width: 'auto', padding: '0 12px', gap: 7, height: 38 }}>
            <HeartIcon filled={savedCount > 0} />
            <span className="fp-disp" style={{ fontSize: 15 }}>{savedCount}</span>
          </button>

          {!mobile && (
            <button className={'fp-reset fp-save' + (view === 'settings' ? ' fp-save--on' : '')} onClick={() => onNav('settings')} title="Settings"
              style={{ width: 38, height: 38, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="var(--fp-ink)" strokeWidth="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 8 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H2a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 3.6 8a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H8a1.65 1.65 0 0 0 1-1.51V2a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V8a1.65 1.65 0 0 0 1.51 1H22a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
            </button>
          )}

          {!mobile && <button className="fp-btn fp-btn--ink fp-btn--sm" onClick={() => onNav('alerts')}>Get alerts</button>}

          {mobile && (
            <button className="fp-reset" onClick={() => setMenu((m) => !m)} style={{ width: 38, height: 38, border: '2px solid var(--fp-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="18" height="18" viewBox="0 0 18 18" stroke="var(--fp-ink)" strokeWidth="2"><path d="M2 4h14M2 9h14M2 14h14"/></svg>
            </button>
          )}
        </div>

        {mobile && menu && (
          <div className="fp-wrap" style={{ paddingBottom: 16, display: 'flex', flexDirection: 'column', gap: 14, borderTop: '1px solid color-mix(in srgb,var(--fp-ink) 14%,transparent)', paddingTop: 14 }}>
            <div style={{ position: 'relative' }}>
              <input className="fp-in" placeholder="Search CF / Lucee…" value={query} onChange={(ev) => onQuery(ev.target.value)} onKeyDown={(ev) => { if (ev.key === 'Enter') { onSearchGo(); setMenu(false); } }} />
            </div>
            {links.map(([id, label]) => <NavLink key={id} id={id} label={label} />)}
            <NavLink id="settings" label="Settings" />
            <button className="fp-btn fp-btn--ink fp-btn--sm" onClick={() => { onNav('alerts'); setMenu(false); }}>Get alerts</button>
          </div>
        )}
      </header>
    );
  }

  // ───────────────────────── Briefing (Today) ─────────────────────────
  function Briefing({ jobs, saved, applied, onOpen, onToggleSave, onApply, onNav }) {
    const top = jobs[0];
    const grid = jobs.slice(1, 7);
    return (
      <div>
        {/* hero color block */}
        <section style={{ background: 'var(--fp-deep)', color: 'var(--fp-cream)' }}>
          <div className="fp-wrap" style={{ padding: '42px 28px 44px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 24, flexWrap: 'wrap' }}>
              <div style={{ flex: '1 1 380px' }}>
                <div className="fp-kick" style={{ color: 'var(--fp-accent)', marginBottom: 16 }}>The daily ColdFusion frontpage · 14 Jun 2026</div>
                <h1 className="fp-disp" style={{ fontSize: 'clamp(44px,7vw,86px)', margin: 0 }}>
                  {STATS.newToday} fresh<br/>CF roles<br/><span style={{ color: 'var(--fp-accent)' }}>worth a look<span style={{ color: 'var(--fp-accent2)' }}>.</span></span>
                </h1>
                <p style={{ fontSize: 16, lineHeight: 1.55, color: 'rgba(243,239,228,0.72)', maxWidth: 440, marginTop: 20 }}>
                  Scored across {STATS.sources} sources, filtered to the {STATS.eligible} that are India-eligible or genuinely remote. No title-only noise.
                </p>
              </div>
              <div className="fp-seal" style={{ width: 132, height: 132, flex: '0 0 auto' }}>
                <svg viewBox="0 0 132 132" width="132" height="132">
                  <defs><path id="fpcircle" d="M66,66 m-50,0 a50,50 0 1,1 100,0 a50,50 0 1,1 -100,0" /></defs>
                  <text fill="var(--fp-accent)" style={{ fontSize: 11, fontWeight: 700, letterSpacing: '3px', fontFamily: 'Archivo' }}>
                    <textPath href="#fpcircle">INDIA-ELIGIBLE · GLOBAL REMOTE · CFML · LUCEE · </textPath>
                  </text>
                </svg>
                <div style={{ position: 'absolute', width: 132, height: 132, marginTop: -132, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span className="fp-disp" style={{ fontSize: 22, color: 'var(--fp-cream)' }}>NEW</span>
                </div>
              </div>
            </div>

            {/* top match strip */}
            <div className="fp-card fp-click" onClick={() => onOpen(top)} style={{ background: 'transparent', borderColor: 'rgba(243,239,228,0.25)', marginTop: 30, padding: 20, display: 'flex', alignItems: 'center', gap: 20, flexWrap: 'wrap' }}>
              <ScoreBadge score={top.score} size={78} onDark />
              <div style={{ flex: '1 1 240px', minWidth: 0 }}>
                <div className="fp-kick" style={{ color: 'var(--fp-accent)', marginBottom: 6 }}>Top match today</div>
                <div className="fp-disp" style={{ fontSize: 'clamp(22px,3vw,30px)', color: 'var(--fp-cream)' }}>{top.title}</div>
                <div style={{ fontSize: 14, color: 'rgba(243,239,228,0.7)', marginTop: 6 }}>{top.company} · {top.loc}</div>
              </div>
              <button className="fp-btn" style={applied.has(top.id) ? { background: 'var(--fp-visited)', color: 'var(--fp-accent-ink)', borderColor: 'var(--fp-ink)' } : { background: 'var(--fp-accent)', color: 'var(--fp-accent-ink)', borderColor: 'var(--fp-ink)' }} onClick={(ev) => { ev.stopPropagation(); onApply(top); }}>{applied.has(top.id) ? 'Applied ✓' : 'Apply now →'}</button>
            </div>
          </div>
        </section>

        {/* more on the board */}
        <section className="fp-wrap" style={{ padding: '30px 28px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 18 }}>
            <span className="fp-disp" style={{ fontSize: 22, whiteSpace: 'nowrap' }}>More on the board</span>
            <span style={{ flex: 1, height: 2, background: 'var(--fp-ink)' }} />
            <button className="fp-reset fp-kick fp-link" style={{ color: 'var(--fp-mute)', whiteSpace: 'nowrap' }} onClick={() => onNav('board')}>See all →</button>
          </div>
          <div className="fp-grid-3">
            {grid.map((j, i) => e(JobCard, { key: j.id, job: j, saved: saved.has(j.id), applied: applied.has(j.id), onOpen, onToggleSave, big: i === 0 }))}
          </div>
        </section>

        {/* by the numbers */}
        <section className="fp-wrap" style={{ padding: '24px 28px 12px' }}>
          <div className="fp-grid-2" style={{ gridTemplateColumns: 'repeat(4,1fr)', gap: 0, border: '2px solid var(--fp-ink)' }}>
            {[['Indexed', STATS.indexed.toLocaleString()], ['New today', '+' + STATS.newToday], ['Eligible 70+', STATS.eligible], ['Live sources', STATS.sources]].map(([l, v], i) => (
              <div key={l} style={{ padding: '20px 22px', borderLeft: i ? '2px solid var(--fp-ink)' : 'none', background: i === 1 ? 'var(--fp-soft)' : 'var(--fp-paper)' }}>
                <div className="fp-disp" style={{ fontSize: 34, color: i === 1 ? 'var(--fp-accent2)' : 'var(--fp-ink)' }}>{v}</div>
                <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 4 }}>{l}</div>
              </div>
            ))}
          </div>
        </section>

        {/* sources strip */}
        <section className="fp-wrap" style={{ padding: '20px 28px 48px' }}>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 12 }}>Reading from {STATS.sources} sources</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {SOURCES.map((s) => <span key={s} className="fp-kick" style={{ padding: '7px 11px', border: '2px solid color-mix(in srgb,var(--fp-ink) 16%,transparent)', color: 'var(--fp-mute)' }}>{s}</span>)}
          </div>
        </section>
      </div>
    );
  }

  // ───────────────────────── Filter bar ─────────────────────────
  function FilterBar({ filters, setFilters, sort, setSort, count, total }) {
    const set = (patch) => setFilters({ ...filters, ...patch });
    const works = [['all', 'All'], ['remote', 'Remote'], ['hybrid', 'Hybrid'], ['onsite', 'Onsite']];
    const scores = [[0, 'Any score'], [70, '70+'], [85, '85+']];
    return (
      <div style={{ position: 'sticky', top: 64, zIndex: 30, background: 'var(--fp-cream)', borderBottom: '2px solid var(--fp-ink)' }}>
        <div className="fp-wrap" style={{ padding: '16px 28px', display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center' }}>
          {works.map(([id, label]) => (
            <button key={id} className={'fp-chip fp-reset' + (filters.work === id ? ' fp-chip--on' : '')} onClick={() => set({ work: id })}>{label}</button>
          ))}
          <span style={{ width: 2, height: 26, background: 'color-mix(in srgb,var(--fp-ink) 16%,transparent)', margin: '0 4px' }} />
          {scores.map(([v, label]) => (
            <button key={v} className={'fp-chip fp-reset' + (filters.minScore === v ? ' fp-chip--on' : '')} onClick={() => set({ minScore: v })}>{label}</button>
          ))}
          <button className={'fp-chip fp-reset' + (filters.eligible ? ' fp-chip--on' : '')} onClick={() => set({ eligible: !filters.eligible })}>India-eligible ✓</button>

          <div style={{ flex: 1 }} />
          <span className="fp-kick" style={{ color: 'var(--fp-mute)' }}>{count} of {total}</span>
          <select className="fp-in" style={{ width: 'auto', padding: '9px 12px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.06em', fontSize: 11 }}
            value={sort} onChange={(ev) => setSort(ev.target.value)}>
            <option value="score">Sort: match score</option>
            <option value="new">Sort: newest</option>
          </select>
        </div>
      </div>
    );
  }

  // ───────────────────────── Board ─────────────────────────
  function Board({ jobs, saved, applied, onOpen, onToggleSave, loading, filters, setFilters, sort, setSort, total, activeCompany, onClearCompany }) {
    return (
      <div>
        <FilterBar filters={filters} setFilters={setFilters} sort={sort} setSort={setSort} count={jobs.length} total={total} />
        <div className="fp-wrap" style={{ padding: '26px 28px 56px' }}>
          {activeCompany && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
              <span className="fp-kick" style={{ color: 'var(--fp-mute)' }}>Filtered to</span>
              <span className="fp-chip fp-chip--on">{activeCompany} ✕</span>
              <button className="fp-reset fp-link fp-kick" style={{ color: 'var(--fp-mute)' }} onClick={onClearCompany}>Clear</button>
            </div>
          )}
          {loading ? e(LoadingGrid)
            : jobs.length === 0 ? e(EmptyState, { title: 'No roles match those filters', body: 'Loosen the score or work-type filters, or clear your search.', cta: 'Reset filters', onCta: () => setFilters({ work: 'all', minScore: 0, eligible: false, companyId: null }) })
            : e('div', { className: 'fp-grid-3' }, jobs.map((j, i) => e(JobCard, { key: j.id, job: j, saved: saved.has(j.id), applied: applied.has(j.id), onOpen, onToggleSave, big: i % 7 === 0 })))}
        </div>
      </div>
    );
  }

  function LoadingGrid() {
    return e('div', { className: 'fp-grid-3' }, [0, 1, 2, 3, 4, 5].map((i) => (
      e('div', { key: i, className: 'fp-card', style: { padding: 22, height: 200, display: 'flex', flexDirection: 'column', gap: 14 } },
        e('div', { style: { display: 'flex', justifyContent: 'space-between' } },
          e('div', { className: 'fp-skel', style: { width: 70, height: 22 } }),
          e('div', { className: 'fp-skel', style: { width: 50, height: 50, borderRadius: '50%' } })),
        e('div', { className: 'fp-skel', style: { width: '85%', height: 26 } }),
        e('div', { className: 'fp-skel', style: { width: '60%', height: 26 } }),
        e('div', { style: { marginTop: 'auto' } }, e('div', { className: 'fp-skel', style: { width: '50%', height: 16 } })))
    )));
  }

  function EmptyState({ title, body, cta, onCta }) {
    return (
      <div className="fp-card" style={{ padding: '56px 32px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
        <div style={{ width: 56, height: 56, borderRadius: '50%', border: '2px solid var(--fp-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--fp-ink)" strokeWidth="2"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg>
        </div>
        <h3 className="fp-disp" style={{ fontSize: 26, margin: 0 }}>{title}</h3>
        <p style={{ margin: 0, color: 'var(--fp-mute)', maxWidth: 360, lineHeight: 1.5 }}>{body}</p>
        {cta && <button className="fp-btn fp-btn--accent" style={{ marginTop: 6 }} onClick={onCta}>{cta}</button>}
      </div>
    );
  }

  // ───────────────────────── Job detail ─────────────────────────
  function JobDetail({ job, saved, applied, appliedSet, onToggleSave, onBack, onOpen, onApply, onAlert, related }) {
    const mobile = useIsMobile(820);
    return (
      <div className="fp-wrap" style={{ padding: '24px 28px 56px' }}>
        <button className="fp-reset fp-link fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 20, display: 'inline-flex', gap: 8 }} onClick={onBack}>← Back to board</button>

        <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1fr 320px', gap: 24, alignItems: 'start' }}>
          {/* main */}
          <div>
            <div className="fp-card" style={{ padding: 28 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 16 }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <WorkPill work={job.work} />
                  <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,40px)', lineHeight: 1.06, margin: '12px 0 14px' }}>{job.title}</h1>
                  <div style={{ fontSize: 16 }}><strong>{job.company}</strong> <span style={{ color: 'var(--fp-mute)' }}>— {job.loc} · posted {job.age} ago</span></div>
                </div>
                {!mobile && <ScoreBadge score={job.score} size={72} />}
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 18 }}>
                {job.stack.map((t) => e(StackTag, { key: t, label: t }))}
              </div>
            </div>

            <div className="fp-card" style={{ padding: 28, marginTop: 16 }}>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 14 }}>About the role</div>
              {job.desc.map((p, i) => <p key={i} style={{ fontSize: 15.5, lineHeight: 1.65, margin: i ? '14px 0 0' : 0 }}>{p}</p>)}
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', margin: '24px 0 12px' }}>Why it scored {job.score}</div>
              <div className="fp-grid-2">
                {job.highlights.map((h) => (
                  <div key={h} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '12px 14px', background: 'var(--fp-soft)', border: '2px solid color-mix(in srgb,var(--fp-ink) 14%,transparent)' }}>
                    <span style={{ color: 'var(--fp-ink)', fontWeight: 800 }}>✓</span>
                    <span style={{ fontSize: 13.5, fontWeight: 600 }}>{h}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* sidebar */}
          <aside style={{ position: mobile ? 'static' : 'sticky', top: 84, display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="fp-card" style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
              {mobile && <ScoreBadge score={job.score} size={64} />}
              {applied
                ? <button className="fp-btn" style={{ width: '100%', background: 'var(--fp-visited)', color: 'var(--fp-accent-ink)', borderColor: 'var(--fp-ink)' }} onClick={() => onApply(job)}>Applied ✓</button>
                : <button className="fp-btn fp-btn--accent" style={{ width: '100%' }} onClick={() => onApply(job)}>Apply now →</button>}
              <div style={{ display: 'flex', gap: 10 }}>
                <button className="fp-btn fp-btn--ghost" style={{ flex: 1 }} onClick={() => onToggleSave(job.id)}>{saved ? '♥ Saved' : '♡ Save'}</button>
                <button className="fp-btn fp-btn--ghost" style={{ flex: 1 }} onClick={() => onAlert('Alert set — we’ll notify you about similar roles.')}>Alert me</button>
              </div>
              <div style={{ borderTop: '2px solid color-mix(in srgb,var(--fp-ink) 14%,transparent)', paddingTop: 14, display: 'flex', flexDirection: 'column', gap: 11 }}>
                {[['Match score', job.score + ' / 100'], ['Work type', job.work], ['Location', job.loc], ['Compensation', job.salary], ['Source', job.source]].map(([k, v]) => (
                  <div key={k} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 14, fontSize: 13 }}>
                    <span className="fp-kick" style={{ color: 'var(--fp-mute)', whiteSpace: 'nowrap', flex: '0 0 auto' }}>{k}</span>
                    <span style={{ fontWeight: 700, textAlign: 'right' }}>{v}</span>
                  </div>
                ))}
              </div>
            </div>
          </aside>
        </div>

        {/* related */}
        {related.length > 0 && (
          <div style={{ marginTop: 36 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 18 }}>
              <span className="fp-disp" style={{ fontSize: 20, whiteSpace: 'nowrap' }}>Related roles</span>
              <span style={{ flex: 1, height: 2, background: 'var(--fp-ink)' }} />
            </div>
            <div className="fp-grid-3">
              {related.map((j) => e(JobCard, { key: j.id, job: j, saved, applied: appliedSet && appliedSet.has(j.id), onOpen, onToggleSave }))}
            </div>
          </div>
        )}
      </div>
    );
  }

  // ───────────────────────── Companies ─────────────────────────
  function Companies({ onOpenCompany }) {
    return (
      <div className="fp-wrap" style={{ padding: '30px 28px 56px' }}>
        <div style={{ marginBottom: 24 }}>
          <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,38px)', margin: 0 }}>Companies hiring CF</h1>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 8 }}>{COMPANIES.length} employers · sorted by match score</div>
        </div>
        <div className="fp-grid-3">
          {COMPANIES.map((c) => (
            <div key={c.id} className="fp-card fp-click" style={{ padding: 22, display: 'flex', flexDirection: 'column', gap: 14, height: '100%' }} onClick={() => onOpenCompany(c)}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div style={{ width: 46, height: 46, border: '2px solid var(--fp-ink)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }} className="fp-disp">{c.name[0]}</div>
                <ScoreBadge score={c.score} size={46} />
              </div>
              <div>
                <h3 className="fp-disp" style={{ fontSize: 22, margin: 0 }}>{c.name}</h3>
                <div style={{ fontSize: 12.5, color: 'var(--fp-mute)', marginTop: 4 }}>{c.sector} · via {c.source}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 'auto', paddingTop: 6 }}>
                <span className="fp-kick" style={{ color: 'var(--fp-ink)' }}>{c.jobs} open {c.jobs === 1 ? 'role' : 'roles'}</span>
                <span className="fp-kick fp-link" style={{ color: 'var(--fp-mute)' }}>View →</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // ───────────────────────── Alerts ─────────────────────────
  function Alerts({ onOpen, jobById, onAlert }) {
    const mobile = useIsMobile(820);
    const unread = ALERTS.filter((a) => !a.read).length;
    return (
      <div className="fp-wrap" style={{ padding: '30px 28px 56px' }}>
        <div style={{ marginBottom: 24 }}>
          <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,38px)', margin: 0 }}>Your alerts</h1>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 8 }}>{ALERTS.length} matches pushed · {unread} unread</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1fr 300px', gap: 24, alignItems: 'start' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {ALERTS.map((a) => {
              const j = jobById[a.jobId];
              if (!j) return null;
              return (
                <div key={a.id} className="fp-card fp-click" style={{ padding: 18, display: 'flex', alignItems: 'center', gap: 16 }} onClick={() => onOpen(j)}>
                  <ScoreBadge score={j.score} size={48} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      {!a.read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--fp-accent2)', border: '1.5px solid var(--fp-ink)', flex: '0 0 auto' }} />}
                      <span className="fp-disp" style={{ fontSize: 19 }}>{j.title}</span>
                    </div>
                    <div style={{ fontSize: 12.5, color: 'var(--fp-mute)', marginTop: 3 }}>{j.company} · {j.loc}</div>
                  </div>
                  <div style={{ textAlign: 'right', flex: '0 0 auto' }}>
                    <div className="fp-kick" style={{ color: 'var(--fp-ink)' }}>{a.channel}</div>
                    <div style={{ fontSize: 11.5, color: 'var(--fp-mute)', marginTop: 4 }}>{a.sentAt}</div>
                  </div>
                </div>
              );
            })}
          </div>
          <aside style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="fp-card" style={{ padding: 22 }}>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 14 }}>Active rules</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {ALERT_RULES.map((r) => (
                  <div key={r.id} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <span style={{ width: 34, height: 20, borderRadius: 12, background: 'var(--fp-accent)', border: '2px solid var(--fp-ink)', position: 'relative', flex: '0 0 auto' }}>
                      <span style={{ position: 'absolute', top: 1, right: 1, width: 14, height: 14, borderRadius: '50%', background: 'var(--fp-ink)' }} />
                    </span>
                    <span style={{ fontSize: 13.5, fontWeight: 600 }}>{r.label}</span>
                  </div>
                ))}
              </div>
              <button className="fp-btn fp-btn--ghost fp-btn--sm" style={{ width: '100%', marginTop: 18 }} onClick={() => onAlert('Rule editor coming soon.')}>Edit rules</button>
            </div>
            <div className="fp-card" style={{ padding: 22, background: 'var(--fp-soft)' }}>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 10 }}>Delivery</div>
              <p style={{ fontSize: 13.5, lineHeight: 1.5, margin: 0 }}>Matches are pushed daily at <strong>06:00</strong> after the pipeline runs — to email and Telegram.</p>
            </div>
          </aside>
        </div>
      </div>
    );
  }

  // ───────────────────────── Saved ─────────────────────────
  function Saved({ jobs, saved, applied, onOpen, onToggleSave, onNav }) {
    return (
      <div className="fp-wrap" style={{ padding: '30px 28px 56px' }}>
        <div style={{ marginBottom: 24 }}>
          <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,38px)', margin: 0 }}>Saved roles</h1>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 8 }}>{jobs.length} saved</div>
        </div>
        {jobs.length === 0
          ? e(EmptyState, { title: 'Nothing saved yet', body: 'Tap the heart on any role to keep it here for later.', cta: 'Browse the board', onCta: () => onNav('board') })
          : e('div', { className: 'fp-grid-3' }, jobs.map((j) => e(JobCard, { key: j.id, job: j, saved: saved.has(j.id), applied: applied.has(j.id), onOpen, onToggleSave })))}
      </div>
    );
  }

  Object.assign(window, { TopNav, Briefing, Board, JobDetail, Companies, Alerts, Saved, EmptyState });
})();

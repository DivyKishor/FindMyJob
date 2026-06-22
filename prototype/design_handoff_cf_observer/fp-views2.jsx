// fp-views2.jsx — additional pages: Company detail, Pipeline (Health),
// Network (Discovery), Settings. Reads data + presentational pieces from
// window; exports the new view components to window.

(function () {
  const e = React.createElement;

  // ───────────────────────── Company detail ─────────────────────────
  function CompanyDetail({ company, jobs, saved, applied, onOpen, onToggleSave, onBack, onViewRoles }) {
    const avg = jobs.length ? Math.round(jobs.reduce((s, j) => s + j.score, 0) / jobs.length) : company.score;
    const sources = [...new Set(jobs.map((j) => j.source))];
    return (
      <div className="fp-wrap" style={{ padding: '24px 28px 56px' }}>
        <button className="fp-reset fp-link fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 20, display: 'inline-flex', gap: 8 }} onClick={onBack}>← Companies</button>

        <div className="fp-card" style={{ padding: 28, display: 'flex', gap: 22, alignItems: 'flex-start', flexWrap: 'wrap' }}>
          <div style={{ width: 72, height: 72, border: '2px solid var(--fp-ink)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }} className="fp-disp"><span style={{ fontSize: 30 }}>{company.name[0]}</span></div>
          <div style={{ flex: '1 1 280px', minWidth: 0 }}>
            <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,40px)', margin: 0 }}>{company.name}</h1>
            <div style={{ fontSize: 14, color: 'var(--fp-mute)', marginTop: 6 }}>{company.sector} · discovered via {company.source}</div>
            <div style={{ display: 'flex', gap: 10, marginTop: 18, flexWrap: 'wrap' }}>
              <button className="fp-btn fp-btn--accent" onClick={onViewRoles}>View all roles →</button>
              <button className="fp-btn fp-btn--ghost" onClick={onBack}>Back to companies</button>
            </div>
          </div>
          <ScoreBadge score={company.score} size={72} />
        </div>

        <div className="fp-grid-3" style={{ marginTop: 16 }}>
          {[['Open roles', jobs.length], ['Avg match', avg], ['Sources', sources.length]].map(([l, v]) => (
            <div key={l} className="fp-card" style={{ padding: 22 }}>
              <div className="fp-disp" style={{ fontSize: 36 }}>{v}</div>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 6 }}>{l}</div>
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 16, margin: '32px 0 18px' }}>
          <span className="fp-disp" style={{ fontSize: 22, whiteSpace: 'nowrap' }}>Open roles at {company.name}</span>
          <span style={{ flex: 1, height: 2, background: 'var(--fp-ink)' }} />
        </div>
        {jobs.length === 0
          ? e(EmptyState, { title: 'No live roles right now', body: 'This employer is on the watch list but has no open CF roles at the moment.' })
          : e('div', { className: 'fp-grid-3' }, jobs.map((j) => e(JobCard, { key: j.id, job: j, saved: saved.has(j.id), applied: applied.has(j.id), onOpen, onToggleSave })))}
      </div>
    );
  }

  // ───────────────────────── Pipeline (Health) ─────────────────────────
  function StatusPill({ status }) {
    const ok = status === 'OK' || status === 'healthy';
    const warn = status === 'WARN';
    const bg = ok ? 'var(--fp-accent)' : warn ? '#ffd24a' : '#ff6a3d';
    return (
      <span className="fp-kick" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '5px 9px', background: bg, color: '#141412', border: '2px solid var(--fp-ink)' }}>
        <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#141412' }} />{status}
      </span>
    );
  }

  function Pipeline({ onAlert }) {
    return (
      <div className="fp-wrap" style={{ padding: '30px 28px 56px' }}>
        <div style={{ marginBottom: 24 }}>
          <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,38px)', margin: 0 }}>Pipeline health</h1>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 8 }}>How today’s {STATS.newToday} roles were found, scored &amp; delivered</div>
        </div>

        {/* status banner */}
        <div className="fp-card" style={{ padding: 22, display: 'flex', alignItems: 'center', gap: 20, flexWrap: 'wrap', background: 'var(--fp-deep)', color: 'var(--fp-cream)', borderColor: 'var(--fp-deep)' }}>
          <span style={{ width: 12, height: 12, borderRadius: '50%', background: 'var(--fp-accent)', flex: '0 0 auto' }} />
          <div style={{ flex: '1 1 200px' }}>
            <div className="fp-disp" style={{ fontSize: 22 }}>Pipeline healthy</div>
            <div style={{ fontSize: 13, color: 'rgba(243,239,228,0.7)', marginTop: 4 }}>Last run {PIPELINE.lastRun} · finished in {PIPELINE.finishedIn}</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="fp-kick" style={{ color: 'var(--fp-accent)' }}>Next scrape</div>
            <div style={{ fontSize: 14, fontWeight: 700, marginTop: 4 }}>{PIPELINE.nextRun}</div>
          </div>
          <button className="fp-btn fp-btn--accent" onClick={() => onAlert('Pipeline run triggered…')}>Run now →</button>
        </div>

        {/* phase timeline */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, margin: '32px 0 16px' }}>
          <span className="fp-disp" style={{ fontSize: 20, whiteSpace: 'nowrap' }}>Run phases</span>
          <span style={{ flex: 1, height: 2, background: 'var(--fp-ink)' }} />
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', gap: 0, border: '2px solid var(--fp-ink)' }} className="fp-phases">
          {PIPELINE.phases.map((p, i) => (
            <div key={p.id} style={{ padding: 18, borderLeft: i ? '2px solid var(--fp-ink)' : 'none', display: 'flex', flexDirection: 'column', gap: 10, minWidth: 0 }}>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)' }}>Step {i + 1}</div>
              <div className="fp-disp" style={{ fontSize: 17 }}>{p.label}</div>
              <StatusPill status={p.status} />
              <div className="fp-disp" style={{ fontSize: 30 }}>{p.volume}</div>
              <div style={{ fontSize: 11.5, color: 'var(--fp-mute)', lineHeight: 1.4 }}>{p.note}</div>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 'auto' }}>{p.sync}</div>
            </div>
          ))}
        </div>

        {/* source health */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, margin: '32px 0 16px' }}>
          <span className="fp-disp" style={{ fontSize: 20, whiteSpace: 'nowrap' }}>Source health</span>
          <span style={{ flex: 1, height: 2, background: 'var(--fp-ink)' }} />
          <span className="fp-kick" style={{ color: 'var(--fp-mute)', whiteSpace: 'nowrap' }}>{SOURCE_HEALTH.length} live sources</span>
        </div>
        <div className="fp-grid-3">
          {SOURCE_HEALTH.map((s) => (
            <div key={s.name} className="fp-card" style={{ padding: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
              <StatusPill status={s.status} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: 14, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.name}</div>
                <div style={{ fontSize: 11.5, color: 'var(--fp-mute)', marginTop: 2 }}>{s.note || ('+' + s.added + ' rows · ' + s.last)}</div>
              </div>
              <span className="fp-disp" style={{ fontSize: 22 }}>{s.added}</span>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // ───────────────────────── Network (Discovery) ─────────────────────────
  function ConfidenceBar({ v }) {
    return (
      <div style={{ width: 90, flex: '0 0 auto' }}>
        <div style={{ height: 8, border: '2px solid var(--fp-ink)', background: 'var(--fp-paper)', position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, width: Math.round(v * 100) + '%', background: 'var(--fp-accent)' }} />
        </div>
        <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 5, fontSize: 10 }}>{Math.round(v * 100)}% conf.</div>
      </div>
    );
  }

  function Network({ onAlert }) {
    return (
      <div className="fp-wrap" style={{ padding: '30px 28px 56px' }}>
        <div style={{ marginBottom: 20 }}>
          <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,38px)', margin: 0 }}>Discovery network</h1>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 8 }}>Who the web is associating with CF / Lucee</div>
        </div>

        <div className="fp-card" style={{ padding: 18, background: 'var(--fp-soft)', marginBottom: 22, display: 'flex', gap: 12, alignItems: 'flex-start' }}>
          <span style={{ fontWeight: 800, fontSize: 18 }}>ⓘ</span>
          <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.55 }}>These are <strong>leads, not postings</strong> — heuristic signals that a company uses ColdFusion. Verify before applying. Confirmed postings live on the <strong>Board</strong>.</p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {DISCOVERY.map((d) => (
            <div key={d.id} className="fp-card" style={{ padding: 18, display: 'flex', alignItems: 'center', gap: 18, flexWrap: 'wrap' }}>
              <div style={{ width: 44, height: 44, border: '2px solid var(--fp-ink)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }} className="fp-disp">{d.company[0]}</div>
              <div style={{ flex: '1 1 240px', minWidth: 0 }}>
                <div className="fp-disp" style={{ fontSize: 19 }}>{d.company}</div>
                <div style={{ fontSize: 13, color: 'var(--fp-mute)', marginTop: 3 }}>{d.signal}</div>
              </div>
              <span className="fp-kick" style={{ color: 'var(--fp-mute)', flex: '0 0 auto' }}>{d.source} · {d.age}</span>
              <ConfidenceBar v={d.confidence} />
              <button className="fp-btn fp-btn--ghost fp-btn--sm" style={{ flex: '0 0 auto' }} onClick={() => onAlert('Added ' + d.company + ' to your watch list')}>Track</button>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // ───────────────────────── Settings ─────────────────────────
  function Toggle({ on, onClick }) {
    return (
      <button className="fp-reset" onClick={onClick} aria-pressed={on}
        style={{ width: 46, height: 26, borderRadius: 14, border: '2px solid var(--fp-ink)', background: on ? 'var(--fp-accent)' : 'var(--fp-paper)', position: 'relative', cursor: 'pointer', flex: '0 0 auto', transition: 'background .15s' }}>
        <span style={{ position: 'absolute', top: 1, left: on ? 22 : 1, width: 18, height: 18, borderRadius: '50%', background: 'var(--fp-ink)', transition: 'left .16s' }} />
      </button>
    );
  }

  function Settings({ onAlert }) {
    const [rules, setRules] = React.useState(() => ALERT_RULES.map((r) => ({ ...r })));
    const [minScore, setMinScore] = React.useState(85);
    const [channels, setChannels] = React.useState({ Email: true, Telegram: true, 'Browser push': false });
    const searches = ['CFML remote 85+', 'Lucee · India-eligible', 'ColdFusion lead roles'];

    const toggleRule = (id) => setRules((rs) => rs.map((r) => r.id === id ? { ...r, active: !r.active } : r));

    return (
      <div className="fp-wrap" style={{ padding: '30px 28px 56px' }}>
        <div style={{ marginBottom: 24 }}>
          <h1 className="fp-disp" style={{ fontSize: 'clamp(28px,4vw,38px)', margin: 0 }}>Settings</h1>
          <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginTop: 8 }}>Alert rules · delivery · saved searches</div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(300px,1fr))', gap: 16, alignItems: 'start' }}>
          {/* alert rules */}
          <div className="fp-card" style={{ padding: 24 }}>
            <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 16 }}>Alert rules</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              {rules.map((r) => (
                <div key={r.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 14 }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{r.label}</span>
                  <Toggle on={r.active} onClick={() => toggleRule(r.id)} />
                </div>
              ))}
            </div>
            <div style={{ borderTop: '2px solid color-mix(in srgb,var(--fp-ink) 14%,transparent)', marginTop: 18, paddingTop: 18 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <span style={{ fontSize: 14, fontWeight: 600 }}>Minimum score</span>
                <span className="fp-disp" style={{ fontSize: 24 }}>{minScore}</span>
              </div>
              <input type="range" min="0" max="100" value={minScore} onChange={(ev) => setMinScore(+ev.target.value)}
                style={{ width: '100%', marginTop: 12, accentColor: 'var(--fp-accent)' }} />
            </div>
          </div>

          {/* delivery */}
          <div className="fp-card" style={{ padding: 24 }}>
            <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 16 }}>Delivery channels</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              {Object.keys(channels).map((c) => (
                <div key={c} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 14 }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{c}</span>
                  <Toggle on={channels[c]} onClick={() => setChannels((s) => ({ ...s, [c]: !s[c] }))} />
                </div>
              ))}
            </div>
            <div className="fp-card" style={{ padding: 14, background: 'var(--fp-soft)', marginTop: 18 }}>
              <p style={{ margin: 0, fontSize: 12.5, lineHeight: 1.5 }}>Matches are delivered daily at <strong>06:00</strong>, right after the pipeline finishes.</p>
            </div>
          </div>

          {/* saved searches + account */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="fp-card" style={{ padding: 24 }}>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 16 }}>Saved searches</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {searches.map((s) => (
                  <div key={s} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, padding: '11px 13px', border: '2px solid color-mix(in srgb,var(--fp-ink) 16%,transparent)' }}>
                    <span style={{ fontSize: 13.5, fontWeight: 600 }}>{s}</span>
                    <span className="fp-kick fp-link" style={{ color: 'var(--fp-mute)', cursor: 'pointer' }}>Run →</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="fp-card" style={{ padding: 24 }}>
              <div className="fp-kick" style={{ color: 'var(--fp-mute)', marginBottom: 14 }}>Account</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 44, height: 44, borderRadius: '50%', border: '2px solid var(--fp-ink)', background: 'var(--fp-accent)', display: 'flex', alignItems: 'center', justifyContent: 'center' }} className="fp-disp">CF</div>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 14 }}>CF Job-seeker</div>
                  <div style={{ fontSize: 12.5, color: 'var(--fp-mute)' }}>you@example.com</div>
                </div>
              </div>
              <button className="fp-btn fp-btn--accent" style={{ width: '100%', marginTop: 18 }} onClick={() => onAlert('Preferences saved')}>Save preferences</button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  Object.assign(window, { CompanyDetail, Pipeline, Network, Settings });
})();

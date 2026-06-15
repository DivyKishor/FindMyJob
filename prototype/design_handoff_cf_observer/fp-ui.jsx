// fp-ui.jsx — Frontpage design system: tokens + presentational components.
// Theme is driven by CSS custom properties on :root so the Tweaks accent
// switch cascades everywhere. Exports presentational pieces to window.

(function () {
  // ── one-time stylesheet (tokens, base, hovers, responsive grids) ──
  if (!document.getElementById('fp-styles')) {
    const s = document.createElement('style');
    s.id = 'fp-styles';
    s.textContent = `
      :root{
        --fp-cream:#f3efe4; --fp-ink:#141412; --fp-paper:#ffffff;
        --fp-accent:#0e93de; --fp-accent-ink:#f3efe4;
        --fp-accent2:#e5322b;
        --fp-visited: color-mix(in srgb, var(--fp-accent) 40%, #837f76);
        --fp-deep:#0a1e3a;
        --fp-mute:#6c685c; --fp-line:#141412;
        --fp-soft: color-mix(in srgb, var(--fp-accent) 16%, #fff);
        --fp-disp:"Bricolage Grotesque", sans-serif;
        --fp-body:"Archivo", sans-serif;
      }
      .fp-root{font-family:var(--fp-body);background:var(--fp-cream);color:var(--fp-ink);
        min-height:100vh;-webkit-font-smoothing:antialiased}
      .fp-root *{box-sizing:border-box}
      .fp-disp{font-family:var(--fp-disp);font-weight:800;letter-spacing:-0.02em;line-height:1.05}
      .fp-kick{font:700 11px/1 var(--fp-body);letter-spacing:.16em;text-transform:uppercase}
      .fp-wrap{max-width:1200px;margin:0 auto;padding:0 28px}
      .fp-reset{all:unset;cursor:pointer;font-family:inherit}

      /* card */
      .fp-card{border:2px solid var(--fp-line);background:var(--fp-paper);position:relative;border-radius:var(--fp-radius,0);
        transition:transform .18s cubic-bezier(.2,.7,.3,1),box-shadow .18s}
      .fp-card.fp-click{cursor:pointer}
      .fp-card.fp-click:hover{transform:translate(-3px,-3px);box-shadow:6px 6px 0 var(--fp-ink)}

      /* buttons */
      .fp-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;
        font:700 13px/1 var(--fp-body);letter-spacing:.04em;text-transform:uppercase;
        padding:13px 22px;border:2px solid var(--fp-ink);border-radius:var(--fp-radius,0);cursor:pointer;transition:transform .14s,background .14s,color .14s;white-space:nowrap}
      .fp-btn:hover{transform:translate(-2px,-2px);box-shadow:4px 4px 0 var(--fp-ink)}
      .fp-btn--accent{background:var(--fp-accent);color:var(--fp-accent-ink)}
      .fp-btn--ink{background:var(--fp-ink);color:var(--fp-cream)}
      .fp-btn--ghost{background:transparent;color:var(--fp-ink)}
      .fp-btn--sm{padding:9px 15px;font-size:11.5px}

      /* chips / pills */
      .fp-chip{display:inline-flex;align-items:center;gap:7px;font:700 11px/1 var(--fp-body);
        letter-spacing:.1em;text-transform:uppercase;padding:8px 13px;border:2px solid var(--fp-ink);border-radius:var(--fp-radius,0);
        background:transparent;color:var(--fp-ink);cursor:pointer;transition:background .14s,color .14s}
      .fp-chip:hover{background:var(--fp-soft)}
      .fp-chip--on{background:var(--fp-accent);color:var(--fp-accent-ink)}

      .fp-save{width:38px;height:38px;border:2px solid var(--fp-ink);border-radius:var(--fp-radius,0);background:var(--fp-paper);
        display:flex;align-items:center;justify-content:center;cursor:pointer;transition:background .14s,transform .12s}
      .fp-save:hover{transform:scale(1.06)}
      .fp-save--on{background:var(--fp-accent)}

      .fp-link{position:relative;cursor:pointer}
      .fp-link::after{content:"";position:absolute;left:0;right:100%;bottom:-3px;height:3px;background:var(--fp-accent);transition:right .22s}
      .fp-link:hover::after,.fp-link.fp-link--on::after{right:0}

      .fp-in{font:500 14px/1 var(--fp-body);padding:12px 14px;border:2px solid var(--fp-ink);border-radius:var(--fp-radius,0);
        background:var(--fp-paper);color:var(--fp-ink);width:100%}
      .fp-in::placeholder{color:var(--fp-mute)}
      .fp-in:focus{outline:none;box-shadow:3px 3px 0 var(--fp-accent)}

      .fp-grid-3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
      .fp-grid-2{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}
      @media (max-width:900px){ .fp-grid-3{grid-template-columns:1fr 1fr} }
      @media (max-width:620px){ .fp-grid-3,.fp-grid-2{grid-template-columns:1fr} .fp-wrap{padding:0 18px} }
      @media (max-width:880px){ .fp-phases{grid-template-columns:1fr 1fr !important} }
      @media (max-width:520px){ .fp-phases{grid-template-columns:1fr !important} }

      @keyframes fp-spin{to{transform:rotate(360deg)}}
      .fp-seal{animation:fp-spin 22s linear infinite}
      @keyframes fp-enter{from{opacity:0}to{opacity:1}}
      .fp-screen{animation:fp-enter .3s ease-out}
      @keyframes fp-pop{0%{opacity:0;transform:translateY(16px) scale(.985)}100%{opacity:1;transform:none}}
      .fp-modal{animation:fp-pop .3s cubic-bezier(.2,.7,.3,1)}
      @keyframes fp-toast-in{from{opacity:0;transform:translate(-50%,14px)}to{opacity:1;transform:translate(-50%,0)}}
      @keyframes fp-check{to{stroke-dashoffset:0}}
      .fp-applied{display:none}
      @keyframes fp-shimmer{0%{background-position:-400px 0}100%{background-position:400px 0}}
      .fp-skel{background:linear-gradient(90deg, color-mix(in srgb,var(--fp-ink) 6%,#fff) 25%, color-mix(in srgb,var(--fp-ink) 12%,#fff) 37%, color-mix(in srgb,var(--fp-ink) 6%,#fff) 63%);
        background-size:800px 100%;animation:fp-shimmer 1.3s linear infinite}
      @media (prefers-reduced-motion: reduce){ .fp-seal{animation:none} .fp-card.fp-click:hover{transform:none} .fp-btn:hover{transform:none} .fp-screen,.fp-modal{animation:none} }
    `;
    document.head.appendChild(s);
  }

  function useIsMobile(bp = 760) {
    const [m, setM] = React.useState(typeof window !== 'undefined' && window.innerWidth <= bp);
    React.useEffect(() => {
      const on = () => setM(window.innerWidth <= bp);
      window.addEventListener('resize', on);
      return () => window.removeEventListener('resize', on);
    }, [bp]);
    return m;
  }

  function ScoreBadge({ score, size = 56, onDark }) {
    const tone = scoreTone(score);
    const bg = tone === 'top' ? 'var(--fp-accent)' : tone === 'good' ? 'var(--fp-paper)' : tone === 'mid' ? 'var(--fp-soft)' : 'transparent';
    const border = onDark ? 'var(--fp-cream)' : 'var(--fp-ink)';
    const col = tone === 'top' ? 'var(--fp-accent-ink)' : (onDark ? 'var(--fp-cream)' : 'var(--fp-ink)');
    return (
      <div style={{ width: size, height: size, borderRadius: '50%', border: '2px solid ' + border, background: bg,
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto', color: col }}>
        <span className="fp-disp" style={{ fontSize: size * 0.36, lineHeight: 1 }}>{score}</span>
        {size >= 56 && <span style={{ fontSize: size * 0.13, fontWeight: 700, letterSpacing: '.1em' }}>MATCH</span>}
      </div>
    );
  }

  function WorkPill({ work }) {
    const on = work === 'remote';
    return <span className="fp-kick" style={{ padding: on ? '5px 9px' : '5px 0', background: on ? 'var(--fp-accent)' : 'transparent', color: on ? 'var(--fp-accent-ink)' : 'var(--fp-mute)' }}>{work}</span>;
  }

  function StackTag({ label }) {
    return <span className="fp-kick" style={{ padding: '6px 10px', border: '2px solid color-mix(in srgb,var(--fp-ink) 18%,transparent)', color: 'var(--fp-mute)' }}>{label}</span>;
  }

  function HeartIcon({ filled }) {
    return (
      <svg width="17" height="17" viewBox="0 0 24 24" fill={filled ? 'var(--fp-ink)' : 'none'} stroke="var(--fp-ink)" strokeWidth="2.2" strokeLinejoin="round">
        <path d="M12 21s-7.5-4.9-10-9.3C.6 9 1.7 5.6 5 4.7c2-.5 3.9.4 5 2 1.1-1.6 3-2.5 5-2 3.3.9 4.4 4.3 3 7C19.5 16.1 12 21 12 21z"/>
      </svg>
    );
  }

  function SaveButton({ saved, onClick, title }) {
    return (
      <button className={'fp-save fp-reset' + (saved ? ' fp-save--on' : '')} onClick={(e) => { e.stopPropagation(); onClick(); }} title={title || (saved ? 'Saved' : 'Save role')} aria-pressed={saved}>
        <HeartIcon filled={saved} />
      </button>
    );
  }

  // Job card — chunky Frontpage card used on briefing + board.
  function JobCard({ job, saved, applied, onOpen, onToggleSave, big }) {
    return (
      <div className="fp-card fp-click" style={{ padding: big ? 26 : 22, display: 'flex', flexDirection: 'column', gap: 13, height: '100%' }} onClick={() => onOpen(job)}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
          <WorkPill work={job.work} />
          <ScoreBadge score={job.score} size={big ? 60 : 50} />
        </div>
        <h3 className="fp-disp" style={{ fontSize: big ? 29 : 22, margin: 0, color: applied ? 'var(--fp-visited)' : 'inherit' }}>{job.title}</h3>
        <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.45, color: 'var(--fp-mute)', display: big ? 'block' : 'none' }}>{job.summary}</p>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12, marginTop: 'auto', paddingTop: 4 }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 700 }}>{job.company}</div>
            <div style={{ fontSize: 12.5, color: 'var(--fp-mute)', marginTop: 2 }}>{job.loc} · {job.age} ago</div>
          </div>
          <SaveButton saved={saved} onClick={() => onToggleSave(job.id)} />
        </div>
      </div>
    );
  }

  function Toast({ msg }) {
    if (!msg) return null;
    return (
      <div style={{ position: 'fixed', left: '50%', bottom: 28, transform: 'translateX(-50%)', zIndex: 60, animation: 'fp-toast-in .3s cubic-bezier(.2,.7,.3,1)',
        background: 'var(--fp-ink)', color: 'var(--fp-cream)', padding: '14px 22px', border: '2px solid var(--fp-ink)',
        boxShadow: '5px 5px 0 var(--fp-accent)', fontSize: 13, fontWeight: 600, letterSpacing: '.02em', display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--fp-accent)' }} />{msg}
      </div>
    );
  }

  Object.assign(window, { useIsMobile, ScoreBadge, WorkPill, StackTag, SaveButton, HeartIcon, JobCard, Toast });
})();

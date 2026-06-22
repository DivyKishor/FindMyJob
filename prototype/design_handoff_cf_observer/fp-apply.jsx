// fp-apply.jsx — Apply flow modal (2 steps: review → sent) + success animation.
// Reads presentational pieces from window; exports ApplyModal to window.

(function () {
  function ApplyModal({ job, applied, onClose, onSubmit }) {
    const [step, setStep] = React.useState(applied ? 2 : 1);
    const [name, setName] = React.useState('CF Job-seeker');
    const [email, setEmail] = React.useState('you@example.com');
    const [note, setNote] = React.useState('');

    React.useEffect(() => {
      const k = (ev) => { if (ev.key === 'Escape') onClose(); };
      document.addEventListener('keydown', k);
      return () => document.removeEventListener('keydown', k);
    }, [onClose]);

    const submit = () => { onSubmit(job.id); setStep(2); };

    const field = (label, value, set, type, ph) => (
      <label style={{ display: 'block' }}>
        <span className="fp-kick" style={{ color: 'var(--fp-mute)', display: 'block', marginBottom: 7 }}>{label}</span>
        {type === 'area'
          ? <textarea className="fp-in" rows="3" placeholder={ph} value={value} onChange={(e) => set(e.target.value)} style={{ resize: 'none', lineHeight: 1.5 }} />
          : <input className="fp-in" type={type} value={value} onChange={(e) => set(e.target.value)} />}
      </label>
    );

    return ReactDOM.createPortal(
      <div onClick={onClose} style={{ position: 'fixed', inset: 0, zIndex: 80, background: 'rgba(10,30,58,0.5)', backdropFilter: 'blur(6px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20, fontFamily: 'var(--fp-body)' }}>
        <div className="fp-card fp-modal" onClick={(e) => e.stopPropagation()} style={{ width: 'min(520px,100%)', maxHeight: '90vh', overflow: 'auto', background: 'var(--fp-cream)', boxShadow: '8px 8px 0 var(--fp-deep)' }}>

          {step === 1 ? (
            <div style={{ padding: 28 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 14 }}>
                <div>
                  <div className="fp-kick" style={{ color: 'var(--fp-accent)', marginBottom: 8 }}>Apply · {job.company}</div>
                  <h2 className="fp-disp" style={{ fontSize: 26, margin: 0, lineHeight: 1.08 }}>{job.title}</h2>
                  <div style={{ fontSize: 13, color: 'var(--fp-mute)', marginTop: 6 }}>{job.loc} · match {job.score}/100</div>
                </div>
                <button className="fp-reset" onClick={onClose} title="Close" style={{ width: 34, height: 34, border: '2px solid var(--fp-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, lineHeight: 1, flex: '0 0 auto' }}>×</button>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 22 }}>
                {field('Full name', name, setName, 'text')}
                {field('Email', email, setEmail, 'email')}
                {field('Note to the team (optional)', note, setNote, 'area', 'Why you’re a fit for this CFML / Lucee role…')}
              </div>

              <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>
                <button className="fp-btn fp-btn--accent" style={{ flex: 1 }} onClick={submit}>Submit application →</button>
                <a className="fp-btn fp-btn--ghost" href="#" onClick={(e) => e.preventDefault()} title="Original posting">Posting ↗</a>
              </div>
              <p style={{ fontSize: 11.5, color: 'var(--fp-mute)', margin: '14px 0 0', lineHeight: 1.5 }}>Prototype only — no application is actually sent. We’ll mark this role as applied on your board.</p>
            </div>
          ) : (
            <div style={{ padding: '40px 28px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 }}>
              <div style={{ width: 76, height: 76, borderRadius: '50%', background: 'var(--fp-accent)', border: '2px solid var(--fp-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="38" height="38" viewBox="0 0 48 48" fill="none" stroke="var(--fp-accent-ink)" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 25l9 9 16-18" style={{ strokeDasharray: 48, animation: 'fp-check .5s ease forwards' }} />
                </svg>
              </div>
              <h2 className="fp-disp" style={{ fontSize: 28, margin: 0 }}>Application sent</h2>
              <p style={{ margin: 0, color: 'var(--fp-mute)', maxWidth: 340, lineHeight: 1.5 }}>
                Your application to <strong style={{ color: 'var(--fp-ink)' }}>{job.company}</strong> for {job.title} is in. It’s now marked <strong style={{ color: 'var(--fp-ink)' }}>Applied</strong> on your board.
              </p>
              <button className="fp-btn fp-btn--ink" style={{ marginTop: 6 }} onClick={onClose}>Done</button>
            </div>
          )}
        </div>
      </div>,
      document.body,
    );
  }

  Object.assign(window, { ApplyModal });
})();

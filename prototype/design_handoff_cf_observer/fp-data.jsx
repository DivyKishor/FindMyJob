// fp-data.jsx — data layer for the Frontpage prototype.
// Richer, realistic CF/CFML/Lucee postings + companies + alerts + sources.
// Companies are invented to avoid recreating any real employer's branding.
// Exported to window so every (separately-compiled) babel file can read them.

(function () {
  const JOBS = [
    { id: 1, title: 'Senior ColdFusion Developer', company: 'Vantage Labs', companyId: 'vantage', loc: 'Remote · Global', region: 'remote-global', work: 'remote', score: 96, age: '2h', postedDays: 0, salary: '$120k–155k', source: 'CF Global Watcher', stack: ['CFML', 'Lucee', 'AWS', 'Postgres'],
      summary: 'Own a high-traffic CFML/Lucee platform serving 40M requests a day on a fully distributed, async-first team.',
      desc: [
        'We run one of the largest ColdFusion deployments still in active development — a Lucee-based platform handling 40M+ requests a day for customers in 30 countries. You will own core services end to end: architecture, performance, and the migration path off legacy CFML modules.',
        'This is a senior, autonomous role on a fully remote team with deliberate timezone overlap windows. We hire globally and pay against senior US bands regardless of location.',
      ],
      highlights: ['Fully remote, hire globally', 'CFML + Lucee named explicitly', 'Senior US comp band', 'Async-first, 4h overlap'] },
    { id: 2, title: 'Lucee Platform Engineer', company: 'Pixl & Co', companyId: 'pixl', loc: 'Remote · India-eligible', region: 'india', work: 'remote', score: 92, age: '4h', postedDays: 0, salary: '₹35–48 LPA', source: 'Adzuna', stack: ['Lucee', 'Docker', 'Postgres', 'Redis'],
      summary: 'Scale a Lucee microservices fleet. INR-friendly contract with EU-hours overlap.',
      desc: [
        'Pixl runs a Lucee microservices fleet behind a creative-asset pipeline. We are looking for a platform engineer to own containerized deploys, observability, and the performance budget across the cluster.',
        'Contract is INR-friendly and explicitly open to India-based engineers, with a few hours of EU overlap expected.',
      ],
      highlights: ['India-eligible', 'Lucee + Docker', 'EU-hours overlap', 'Platform ownership'] },
    { id: 3, title: 'Full-Stack Engineer (CFML / Node)', company: 'emsCharts', companyId: 'emscharts', loc: 'Bengaluru, IN · Hybrid', region: 'india', work: 'hybrid', score: 90, age: '5h', postedDays: 0, salary: '₹28–40 LPA', source: 'Greenhouse', stack: ['CFML', 'Node', 'Vue', 'SQL Server'],
      summary: 'Bridge a legacy CFML core and a modern Node/Vue front end for healthcare logistics.',
      desc: [
        'You will work across a CFML service core and a newer Node + Vue front end powering emergency-services charting. Strong CFML fundamentals required; we will support you ramping on the JS side.',
        'Hybrid in Bengaluru — 3 days on-site, 2 remote.',
      ],
      highlights: ['Bengaluru hybrid', 'CFML + Node/Vue', 'Healthcare domain', '3/2 hybrid split'] },
    { id: 4, title: 'Full-Stack ColdFusion Lead', company: 'Meridian Bank', companyId: 'meridian', loc: 'Hyderabad, IN · Hybrid', region: 'india', work: 'hybrid', score: 88, age: '8h', postedDays: 0, salary: '₹45–60 LPA', source: 'LinkedIn', stack: ['ColdFusion', 'Oracle', 'Team Lead'],
      summary: 'Lead a small CF team modernizing core banking workflows on ColdFusion + Oracle.',
      desc: [
        'Meridian is modernizing a long-running ColdFusion banking platform. As lead you will mentor a team of four, set technical direction, and own the relationship with the Oracle DBA group.',
        'Hybrid in Hyderabad. Prior CF team-lead experience strongly preferred.',
      ],
      highlights: ['Team lead role', 'Hyderabad hybrid', 'Banking / Oracle', 'Mentor a team of 4'] },
    { id: 5, title: 'ColdFusion Application Developer', company: 'Northwind Retail', companyId: 'northwind', loc: 'Pune, IN · Onsite', region: 'india', work: 'onsite', score: 76, age: '1d', postedDays: 1, salary: '₹18–26 LPA', source: 'Foundit', stack: ['CFML', 'SQL', 'jQuery'],
      summary: 'Maintain and extend retail back-office apps built on ColdFusion.',
      desc: [
        'Day-to-day work on order-management and inventory tools written in ColdFusion, backed by SQL Server. A steady, product-support oriented role.',
        'On-site in Pune, standard hours.',
      ],
      highlights: ['Pune onsite', 'Retail back-office', 'CFML + SQL', 'Steady product work'] },
    { id: 6, title: 'Mura CMS Developer', company: 'Blue Mango Studio', companyId: 'bluemango', loc: 'Remote · Worldwide', region: 'remote-global', work: 'remote', score: 72, age: '1d', postedDays: 1, salary: '$70k–95k', source: 'GetCFMLJobs', stack: ['Mura', 'CFML', 'JS', 'CSS'],
      summary: 'Build client sites on Mura CMS at a small, fully-remote agency.',
      desc: [
        'A boutique agency building content sites on Mura (CFML). You will work across templating, custom modules, and the occasional integration. Variety of client work, low bureaucracy.',
        'Fully remote, worldwide, with loose hours.',
      ],
      highlights: ['Fully remote', 'Mura CMS', 'Agency variety', 'Loose hours'] },
    { id: 7, title: 'CFML Backend Developer', company: 'Right People Group', companyId: 'rightpeople', loc: 'Remote · EU hours', region: 'remote-eu', work: 'remote', score: 70, age: '2d', postedDays: 2, salary: '€55k–70k', source: 'Remotive', stack: ['CFML', 'REST', 'MySQL'],
      summary: 'Contract CFML backend work on REST services for European clients.',
      desc: [
        'Recruiter-led contract placing CFML backend developers with European product teams. Current opening is REST API work on a MySQL-backed platform.',
        'Remote within EU hours.',
      ],
      highlights: ['Remote, EU hours', 'Contract', 'REST + MySQL', 'Recruiter-placed'] },
    { id: 8, title: 'Senior CF / Lucee Engineer', company: 'Helios Health', companyId: 'helios', loc: 'Remote · US work-auth', region: 'remote-us', work: 'remote', score: 52, age: '2d', postedDays: 2, salary: '$110k–140k', source: 'USAJOBS', stack: ['Lucee', 'HIPAA', 'SQL'],
      summary: 'Senior Lucee role on a HIPAA-regulated platform — US work authorization required.',
      desc: [
        'Strong Lucee role, but gated on US work authorization and a background check due to HIPAA scope. Listed for completeness; scores lower on the eligibility layer for non-US applicants.',
        'Remote within the US.',
      ],
      highlights: ['US work-auth required', 'HIPAA scope', 'Lucee senior', 'Lower eligibility'] },
    { id: 9, title: 'ColdFusion / CFWheels Developer', company: 'Cadence Apps', companyId: 'cadence', loc: 'Remote · India-eligible', region: 'india', work: 'remote', score: 84, age: '3d', postedDays: 3, salary: '₹22–34 LPA', source: 'Cutshort', stack: ['CFML', 'CFWheels', 'Vue'],
      summary: 'Product engineering on a CFWheels app with a Vue front end.',
      desc: [
        'Cadence builds scheduling software on CFWheels (CFML). You will ship features across the stack with a Vue front end and a small, senior team.',
        'Remote, open to India-based engineers.',
      ],
      highlights: ['India-eligible remote', 'CFWheels', 'Product team', 'Small senior team'] },
    { id: 10, title: 'Lead ColdFusion Architect', company: 'Atlas Logistics', companyId: 'atlas', loc: 'Remote · Global', region: 'remote-global', work: 'remote', score: 94, age: '3d', postedDays: 3, salary: '$140k–180k', source: 'CF Global Watcher', stack: ['ColdFusion', 'Lucee', 'Architecture', 'AWS'],
      summary: 'Set architecture for a global logistics platform mid-migration from Adobe CF to Lucee.',
      desc: [
        'Atlas is mid-migration from Adobe ColdFusion to Lucee across a global logistics platform. We need an architect to own the strategy, de-risk the cutover, and level up the team.',
        'Fully remote, global, senior comp.',
      ],
      highlights: ['Architecture role', 'Adobe CF → Lucee', 'Fully remote global', 'Senior comp'] },
    { id: 11, title: 'CFML Developer (Contract)', company: 'Foundry Digital', companyId: 'foundry', loc: 'Remote · Worldwide', region: 'remote-global', work: 'remote', score: 78, age: '4d', postedDays: 4, salary: '$55–75 / hr', source: 'We Work Remotely', stack: ['CFML', 'Coldbox', 'REST'],
      summary: '6-month CFML contract on a ColdBox API, fully remote and worldwide.',
      desc: [
        'Short-term contract extending a ColdBox (CFML) API. Clear scope, friendly team, possibility to extend.',
        'Fully remote, worldwide.',
      ],
      highlights: ['6-month contract', 'ColdBox', 'Remote worldwide', 'Possible extension'] },
    { id: 12, title: 'Junior ColdFusion Developer', company: 'Northwind Retail', companyId: 'northwind', loc: 'Pune, IN · Onsite', region: 'india', work: 'onsite', score: 68, age: '5d', postedDays: 5, salary: '₹8–14 LPA', source: 'Shine', stack: ['CFML', 'SQL'],
      summary: 'Entry-level CF role maintaining retail tools — training provided.',
      desc: [
        'Good first job for someone with basic CFML and SQL. You will pair with senior devs on the retail platform and grow into ownership.',
        'On-site in Pune.',
      ],
      highlights: ['Entry level', 'Pune onsite', 'Training provided', 'CFML + SQL'] },
    { id: 13, title: 'Full-Stack Lucee Engineer', company: 'Pixl & Co', companyId: 'pixl', loc: 'Remote · India-eligible', region: 'india', work: 'remote', score: 86, age: '6d', postedDays: 6, salary: '₹26–38 LPA', source: 'Weekday', stack: ['Lucee', 'Svelte', 'Postgres'],
      summary: 'Full-stack role pairing Lucee services with a Svelte front end.',
      desc: [
        'Second opening at Pixl — full-stack this time, pairing Lucee back-end services with a Svelte front end. Strong product focus.',
        'Remote, India-eligible.',
      ],
      highlights: ['India-eligible', 'Lucee + Svelte', 'Product focus', 'Full-stack'] },
    { id: 14, title: 'ColdFusion Support Engineer', company: 'Helios Health', companyId: 'helios', loc: 'Hybrid · Chennai, IN', region: 'india', work: 'hybrid', score: 74, age: '6d', postedDays: 6, salary: '₹16–24 LPA', source: 'Instahyre', stack: ['CFML', 'SQL', 'Support'],
      summary: 'Production support for CF applications with a path into development.',
      desc: [
        'Tier-2/3 support for ColdFusion applications: triage, hotfixes, and small enhancements, with a clear path into full development.',
        'Hybrid in Chennai.',
      ],
      highlights: ['Chennai hybrid', 'Support → dev path', 'CFML', 'Production triage'] },
  ];

  const COMPANIES = [
    { id: 'vantage', name: 'Vantage Labs', sector: 'Developer tools', source: 'CF Global Watcher', score: 96, jobs: 1, hiring: true },
    { id: 'atlas', name: 'Atlas Logistics', sector: 'Logistics', source: 'CF Global Watcher', score: 94, jobs: 1, hiring: true },
    { id: 'pixl', name: 'Pixl & Co', sector: 'Creative SaaS', source: 'Adzuna', score: 92, jobs: 2, hiring: true },
    { id: 'emscharts', name: 'emsCharts', sector: 'Healthcare', source: 'Greenhouse', score: 90, jobs: 1, hiring: true },
    { id: 'meridian', name: 'Meridian Bank', sector: 'Finance', source: 'LinkedIn', score: 88, jobs: 1, hiring: true },
    { id: 'cadence', name: 'Cadence Apps', sector: 'Scheduling SaaS', source: 'Cutshort', score: 84, jobs: 1, hiring: true },
    { id: 'foundry', name: 'Foundry Digital', sector: 'Agency', source: 'We Work Remotely', score: 78, jobs: 1, hiring: true },
    { id: 'bluemango', name: 'Blue Mango Studio', sector: 'Agency', source: 'GetCFMLJobs', score: 72, jobs: 1, hiring: true },
    { id: 'northwind', name: 'Northwind Retail', sector: 'Retail', source: 'Foundit', score: 76, jobs: 2, hiring: true },
    { id: 'rightpeople', name: 'Right People Group', sector: 'Recruiter', source: 'Remotive', score: 70, jobs: 1, hiring: true },
    { id: 'helios', name: 'Helios Health', sector: 'Healthcare', source: 'USAJOBS', score: 74, jobs: 2, hiring: true },
  ];

  // Pre-triggered alerts (what the daily pipeline has already pushed).
  const ALERTS = [
    { id: 'a1', jobId: 1, channel: 'Email', sentAt: 'Today · 06:02', read: false },
    { id: 'a2', jobId: 10, channel: 'Email', sentAt: 'Today · 06:02', read: false },
    { id: 'a3', jobId: 2, channel: 'Telegram', sentAt: 'Today · 06:02', read: true },
    { id: 'a4', jobId: 9, channel: 'Email', sentAt: 'Yesterday · 06:01', read: true },
    { id: 'a5', jobId: 13, channel: 'Telegram', sentAt: 'Yesterday · 06:01', read: true },
  ];

  const ALERT_RULES = [
    { id: 'r1', label: 'Score ≥ 85', active: true },
    { id: 'r2', label: 'India-eligible or global remote', active: true },
    { id: 'r3', label: 'CFML or Lucee in stack', active: true },
    { id: 'r4', label: 'Posted within 24h', active: true },
  ];

  const SOURCES = ['CF Global Watcher', 'Adzuna', 'Remotive', 'GetCFMLJobs', 'Greenhouse', 'We Work Remotely', 'USAJOBS', 'Reddit', 'Jooble', 'DevJobsScanner', 'Cutshort', 'Foundit'];

  const STATS = { indexed: 1284, newToday: 47, sources: 22, eligible: 312 };

  // Pipeline run — phases of the daily engine (watcher → discovery → scrape → score → alerts).
  const PIPELINE = {
    lastRun: 'Today · 06:00',
    finishedIn: '2m 16s',
    status: 'healthy',
    nextRun: 'Tomorrow · 06:00',
    nextExpiry: 'in 2 days · 03:00',
    phases: [
      { id: 'watcher', label: 'CF Global Watcher', status: 'OK', sync: '06:00:04', volume: 38, note: 'Bing RSS + page fetch' },
      { id: 'discovery', label: 'Discovery', status: 'OK', sync: '06:00:31', volume: 62, note: 'Stack / community queries' },
      { id: 'scrape', label: 'Scrape · runAll', status: 'OK', sync: '06:02:10', volume: 284, note: 'Boards + ATS + enrich' },
      { id: 'score', label: 'Score', status: 'OK', sync: '06:02:18', volume: 284, note: 'v3 India-eligible rules' },
      { id: 'alerts', label: 'Alerts', status: 'WARN', sync: '06:02:20', volume: 5, note: 'Telegram rate-limited once' },
    ],
  };

  // Per-source health for the pipeline page.
  const SOURCE_HEALTH = [
    { name: 'CF Global Watcher', status: 'OK', last: '06:00', added: 38 },
    { name: 'Adzuna', status: 'OK', last: '06:01', added: 24 },
    { name: 'Remotive', status: 'OK', last: '06:01', added: 12 },
    { name: 'GetCFMLJobs', status: 'OK', last: '06:01', added: 6 },
    { name: 'Greenhouse', status: 'OK', last: '06:01', added: 19 },
    { name: 'We Work Remotely', status: 'OK', last: '06:01', added: 8 },
    { name: 'USAJOBS', status: 'OK', last: '06:01', added: 9 },
    { name: 'Reddit', status: 'WARN', last: '06:02', added: 3, note: 'Throttled — retried' },
    { name: 'Jooble', status: 'OK', last: '06:02', added: 4 },
    { name: 'DevJobsScanner', status: 'OK', last: '06:02', added: 7 },
    { name: 'Cutshort', status: 'OK', last: '06:02', added: 5 },
    { name: 'Foundit', status: 'WARN', last: '06:02', added: 0, note: 'No new rows' },
  ];

  // Discovery signals — leads (who the web associates with CF/Lucee), NOT postings.
  const DISCOVERY = [
    { id: 'd1', company: 'Equinox Travel', signal: 'Careers page lists ColdFusion as core stack', source: 'CF Global Watcher', confidence: 0.92, age: '3h' },
    { id: 'd2', company: 'Granite Mutual', signal: 'Lucee named in a public job ad', source: 'Bing RSS', confidence: 0.84, age: '6h' },
    { id: 'd3', company: 'Harbor Logistics', signal: 'CFML files detected on public domain', source: 'CF Global Watcher', confidence: 0.78, age: '11h' },
    { id: 'd4', company: 'Veridian Media', signal: 'Engineer mentions Mura CMS on r/coldfusion', source: 'Reddit', confidence: 0.61, age: '1d' },
    { id: 'd5', company: 'Pinecrest Bank', signal: 'Adobe ColdFusion in a procurement notice', source: 'Open web', confidence: 0.74, age: '1d' },
    { id: 'd6', company: 'Solstice Retail', signal: 'CFWheels referenced in a conference talk', source: 'DevJobsScanner', confidence: 0.55, age: '2d' },
    { id: 'd7', company: 'Northwind Retail', signal: 'Second CF role posted this week', source: 'Foundit', confidence: 0.88, age: '2d' },
    { id: 'd8', company: 'Atlas Logistics', signal: 'Migration from Adobe CF to Lucee announced', source: 'CF Global Watcher', confidence: 0.95, age: '3d' },
  ];

  function scoreTone(s) {
    if (s >= 90) return 'top';
    if (s >= 70) return 'good';
    if (s >= 50) return 'mid';
    return 'low';
  }

  Object.assign(window, { JOBS, COMPANIES, ALERTS, ALERT_RULES, SOURCES, STATS, PIPELINE, SOURCE_HEALTH, DISCOVERY, scoreTone });
})();

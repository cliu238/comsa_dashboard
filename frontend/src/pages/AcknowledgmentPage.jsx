import { AWARD, ORGS, INVESTIGATORS, CONTRIBUTORS } from '../content/links';

function initials(name) {
  return name.split(/\s+/).filter(Boolean).map((w) => w[0]).slice(0, 2).join('').toUpperCase();
}

export function InvestigatorCard({ person }) {
  const { name, role, affiliation, url, photo } = person;
  const nameEl = url
    ? <a href={url} target="_blank" rel="noopener noreferrer">{name}</a>
    : name;
  return (
    <div className="person-card">
      {photo
        ? <img className="person-photo" src={`${import.meta.env.BASE_URL}${photo}`} alt={name} />
        : <div className="person-avatar" aria-hidden="true">{initials(name)}</div>}
      <div className="person-info">
        <span className="person-name">{nameEl}</span>
        {role && <span className="person-role">{role}</span>}
        {affiliation && <span className="person-affiliation">{affiliation}</span>}
      </div>
    </div>
  );
}

export default function AcknowledgmentPage() {
  return (
    <div className="content-page">
      <section className="content-section">
        <h2>Award</h2>
        <p>
          This work was supported by the{' '}
          <a href={AWARD.url} target="_blank" rel="noopener noreferrer">{AWARD.title}</a>{' '}
          from the{' '}
          <a href={ORGS.dsai.url} target="_blank" rel="noopener noreferrer">{ORGS.dsai.name}</a>.
        </p>
      </section>

      <section className="content-section">
        <h2>Investigators</h2>
        <div className="person-grid">
          {INVESTIGATORS.map((p) => <InvestigatorCard key={p.name} person={p} />)}
        </div>
      </section>

      <section className="content-section">
        <h2>Contributors</h2>
        <p>
          Platform designed and developed by the{' '}
          <a href={ORGS.dsai.url} target="_blank" rel="noopener noreferrer">{ORGS.dsai.name}</a>,{' '}
          <a href={ORGS.biostat.url} target="_blank" rel="noopener noreferrer">{ORGS.biostat.name}</a>, and{' '}
          <a href={ORGS.intlHealth.url} target="_blank" rel="noopener noreferrer">{ORGS.intlHealth.name}</a>{' '}
          at Johns Hopkins.
        </p>
        <div className="person-grid">
          {CONTRIBUTORS.map((p) => <InvestigatorCard key={p.name} person={p} />)}
        </div>
      </section>
    </div>
  );
}

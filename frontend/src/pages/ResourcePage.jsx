import VideosSection from '../components/VideosSection';
import { PACKAGE_LINKS, REFERENCES, SAMPLE_DATA_SOURCE } from '../content/links';

export default function ResourcePage() {
  return (
    <div className="content-page">
      <section className="content-section">
        <h2>vacalibration R Package</h2>
        <ul className="link-list">
          <li>
            <a href={PACKAGE_LINKS.github} target="_blank" rel="noopener noreferrer">GitHub repository</a>
          </li>
          <li>
            <a href={PACKAGE_LINKS.cran} target="_blank" rel="noopener noreferrer">CRAN package page</a>
          </li>
        </ul>
      </section>

      <section className="content-section">
        <h2>References</h2>
        <ol className="reference-list">
          {REFERENCES.map((r) => (
            <li key={r.url}>
              {r.authors} ({r.year}). {r.title}. <em>{r.venue}.</em>{' '}
              <a href={r.url} target="_blank" rel="noopener noreferrer" aria-label={r.title}>Link</a>
            </li>
          ))}
        </ol>
      </section>

      <section className="content-section">
        <h2>Sample Data Source</h2>
        <p className="sample-source">
          {SAMPLE_DATA_SOURCE.text}{' '}
          <a href={SAMPLE_DATA_SOURCE.url} target="_blank" rel="noopener noreferrer">GitHub</a>
        </p>
      </section>

      <VideosSection defaultExpanded />
    </div>
  );
}

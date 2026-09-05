import type { Metadata } from 'next';
import './globals.css';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'PRAHAR — Expert Triage Console',
  description: 'Agronomist & System Admin Console for Precision Agriculture',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <nav className="navbar">
          <div className="nav-brand">
            <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span>PRAHAR</span>
              <span className="badge">Console v0.2</span>
            </Link>
          </div>
          <div className="nav-links">
            <Link href="/" className="nav-link">Overview</Link>
            <Link href="/queue" className="nav-link">Triage Queue</Link>
            <Link href="/closed-loop" className="nav-link">Closed-Loop</Link>
            <Link href="/fleet" className="nav-link">Fleet Telemetry</Link>
          </div>
        </nav>
        <main className="container">{children}</main>
      </body>
    </html>
  );
}

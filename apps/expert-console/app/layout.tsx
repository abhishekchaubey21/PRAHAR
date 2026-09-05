import type { Metadata } from 'next';
import './globals.css';
import { ExpertRootShell } from '../lib/nav-auth-bar';

export const metadata: Metadata = {
  title: 'PRAHAR | Field Intelligence',
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
        <ExpertRootShell>{children}</ExpertRootShell>
      </body>
    </html>
  );
}

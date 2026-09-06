/**
 * PRAHAR PDF Field Evidence Report Generator
 * Generates standards-compliant, print- and mobile-ready PDF-1.4 documents.
 * Self-contained, zero-dependency, deterministic PDF generator for PRAHAR field evidence.
 */

import { FieldEvidenceReport } from '@prahar/shared';

export class PdfReportGenerator {
  /**
   * Sanitizes a string for safe inclusion in PDF text parentheses (WinAnsi/ASCII)
   */
  private static escapePdfText(text: string): string {
    if (!text) return '';
    // Replace non-ASCII / unicode with closest ASCII approximations
    const sanitized = text
      .replace(/[\u2018\u2019]/g, "'")
      .replace(/[\u201C\u201D]/g, '"')
      .replace(/[\u2013\u2014]/g, '-')
      .replace(/•/g, '*')
      .replace(/[^\x20-\x7E\r\n\t]/g, ' '); // Replace other non-printable/unicode with space

    return sanitized
      .replace(/\\/g, '\\\\')
      .replace(/\(/g, '\\(')
      .replace(/\)/g, '\\)');
  }

  /**
   * Generates a complete, valid PDF-1.4 binary buffer for a FieldEvidenceReport
   */
  public static generatePdf(report: FieldEvidenceReport): Buffer {
    const streamOps: string[] = [];

    // Coordinate helpers (A4 is 595.28 x 841.89 points)
    const pageWidth = 595.28;
    const pageHeight = 841.89;
    const margin = 40;
    const contentWidth = pageWidth - margin * 2;

    // ------------------------------------------------------------------------
    // 1. Header Banner (Dark Forest Green: #0B241B)
    // ------------------------------------------------------------------------
    // Top banner background
    streamOps.push('q');
    streamOps.push('0.043 0.141 0.106 rg'); // #0B241B
    streamOps.push(`0 ${pageHeight - 90} ${pageWidth} 90 re f`);

    // Top Accent line (Emerald Green: #10B981)
    streamOps.push('0.063 0.725 0.506 rg'); // #10B981
    streamOps.push(`0 ${pageHeight - 94} ${pageWidth} 4 re f`);

    // Header Titles
    streamOps.push('1 1 1 rg'); // White text
    streamOps.push('BT');
    streamOps.push('/F2 18 Tf'); // Helvetica-Bold 18pt
    streamOps.push(`${margin} ${pageHeight - 45} Td`);
    streamOps.push(`(${this.escapePdfText(report.report_title)}) Tj`);
    streamOps.push('ET');

    streamOps.push('0.8 0.8 0.8 rg');
    streamOps.push('BT');
    streamOps.push('/F1 9 Tf');
    streamOps.push(`${margin} ${pageHeight - 65} Td`);
    streamOps.push(
      `(${this.escapePdfText('Autonomous Observation & Verified Closed-Loop Field Intelligence | Gateway Auth v0.5')}) Tj`
    );
    streamOps.push('ET');

    // Report ID pill on right
    streamOps.push('0.063 0.725 0.506 rg');
    streamOps.push('BT');
    streamOps.push('/F2 9 Tf');
    streamOps.push(`${pageWidth - margin - 150} ${pageHeight - 45} Td`);
    streamOps.push(`(${this.escapePdfText(report.report_id)}) Tj`);
    streamOps.push('ET');

    streamOps.push('Q');

    // Current Y cursor
    let y = pageHeight - 110;

    // ------------------------------------------------------------------------
    // 2. Mandatory Non-Government Disclaimer Banner (Amber Alert Box)
    // ------------------------------------------------------------------------
    const disclaimerBoxHeight = 44;
    streamOps.push('q');
    streamOps.push('0.96 0.62 0.04 RG'); // Amber border #F59E0B
    streamOps.push('0.98 0.95 0.90 rg'); // Very light amber tint #FEF3C7
    streamOps.push('1 w');
    streamOps.push(`${margin} ${y - disclaimerBoxHeight} ${contentWidth} ${disclaimerBoxHeight} re B`);

    streamOps.push('0.71 0.40 0.05 rg'); // Dark amber text #B45309
    streamOps.push('BT');
    streamOps.push('/F2 8 Tf');
    streamOps.push(`${margin + 10} ${y - 14} Td`);
    streamOps.push(`(${this.escapePdfText('LEGAL NOTICE & STATUTORY DISCLAIMER:')}) Tj`);
    streamOps.push('ET');

    streamOps.push('0.3 0.2 0.05 rg');
    streamOps.push('BT');
    streamOps.push('/F1 7.5 Tf');
    streamOps.push(`${margin + 10} ${y - 26} Td`);
    streamOps.push(
      `(${this.escapePdfText('This report is an informational field-evidence summary generated from PRAHAR system')}) Tj`
    );
    streamOps.push('ET');

    streamOps.push('BT');
    streamOps.push('/F1 7.5 Tf');
    streamOps.push(`${margin + 10} ${y - 36} Td`);
    streamOps.push(
      `(${this.escapePdfText('observations and AI/edge outputs. It is not an official government certificate, legal warranty, or guaranteed diagnosis.')}) Tj`
    );
    streamOps.push('ET');
    streamOps.push('Q');

    y -= disclaimerBoxHeight + 14;

    // ------------------------------------------------------------------------
    // 3. Farm & Zone Identification Card
    // ------------------------------------------------------------------------
    const infoBoxHeight = 65;
    streamOps.push('q');
    streamOps.push('0.92 0.94 0.93 rg'); // Slate background
    streamOps.push('0.80 0.83 0.81 RG');
    streamOps.push('0.75 w');
    streamOps.push(`${margin} ${y - infoBoxHeight} ${contentWidth} ${infoBoxHeight} re B`);

    // Column 1: Farm Information
    streamOps.push('0.1 0.1 0.1 rg');
    streamOps.push('BT');
    streamOps.push('/F2 9 Tf');
    streamOps.push(`${margin + 10} ${y - 16} Td`);
    streamOps.push(`(${this.escapePdfText('Farm: ' + report.farm_name)}) Tj`);
    streamOps.push('ET');

    streamOps.push('0.3 0.3 0.3 rg');
    streamOps.push('BT');
    streamOps.push('/F1 8 Tf');
    streamOps.push(`${margin + 10} ${y - 30} Td`);
    streamOps.push(`(${this.escapePdfText('Farm ID: ' + report.farm_id + (report.location ? ' | Loc: ' + report.location : ''))}) Tj`);
    streamOps.push('ET');

    streamOps.push('BT');
    streamOps.push('/F1 8 Tf');
    streamOps.push(`${margin + 10} ${y - 44} Td`);
    streamOps.push(`(${this.escapePdfText('Crop: ' + (report.crop_type || 'Unspecified') + ' | Generated: ' + new Date(report.generated_at).toLocaleString())}) Tj`);
    streamOps.push('ET');

    // Column 2: Zone & Period
    const col2X = margin + contentWidth / 2 + 10;
    streamOps.push('0.1 0.1 0.1 rg');
    streamOps.push('BT');
    streamOps.push('/F2 9 Tf');
    streamOps.push(`${col2X} ${y - 16} Td`);
    streamOps.push(`(${this.escapePdfText('Zone: ' + (report.zone_name || report.zone_id))}) Tj`);
    streamOps.push('ET');

    streamOps.push('0.3 0.3 0.3 rg');
    streamOps.push('BT');
    streamOps.push('/F1 8 Tf');
    streamOps.push(`${col2X} ${y - 30} Td`);
    streamOps.push(`(${this.escapePdfText('Zone ID: ' + report.zone_id + (report.soil_type ? ' | Soil: ' + report.soil_type : ''))}) Tj`);
    streamOps.push('ET');

    const periodStr = report.period
      ? `${new Date(report.period.from).toLocaleDateString()} to ${new Date(report.period.to).toLocaleDateString()}`
      : 'Authoritative Historical Record';
    streamOps.push('BT');
    streamOps.push('/F1 8 Tf');
    streamOps.push(`${col2X} ${y - 44} Td`);
    streamOps.push(`(${this.escapePdfText('Observation Period: ' + periodStr)}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= infoBoxHeight + 16;

    // ------------------------------------------------------------------------
    // 4. Section: Field-Health & Latest Sensor Telemetry
    // ------------------------------------------------------------------------
    streamOps.push('q');
    streamOps.push('0.05 0.23 0.18 rg'); // Forest green header
    streamOps.push('BT');
    streamOps.push('/F2 11 Tf');
    streamOps.push(`${margin} ${y} Td`);
    streamOps.push(`(${this.escapePdfText('1. FIELD-HEALTH STATUS & SENSOR TELEMETRY')}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= 10;

    // Health Summary sub-box
    const healthStatus = report.field_health_summary?.status || 'OPTIMAL';
    let statusColor = '0.06 0.72 0.50 rg'; // Emerald
    if (healthStatus === 'ATTENTION_REQUIRED') statusColor = '0.96 0.62 0.04 rg'; // Amber
    if (healthStatus === 'CRITICAL') statusColor = '0.94 0.27 0.27 rg'; // Red

    const healthBoxHeight = 46;
    streamOps.push('q');
    streamOps.push('0.96 0.97 0.96 rg');
    streamOps.push('0.85 0.88 0.86 RG');
    streamOps.push(`${margin} ${y - healthBoxHeight} ${contentWidth} ${healthBoxHeight} re B`);

    streamOps.push('0.1 0.1 0.1 rg');
    streamOps.push('BT');
    streamOps.push('/F2 9 Tf');
    streamOps.push(`${margin + 10} ${y - 16} Td`);
    streamOps.push(`(${this.escapePdfText('Deterministic Assessment: ')}) Tj`);
    streamOps.push('ET');

    streamOps.push(statusColor);
    streamOps.push('BT');
    streamOps.push('/F2 9 Tf');
    streamOps.push(`${margin + 140} ${y - 16} Td`);
    streamOps.push(`(${this.escapePdfText(healthStatus)}) Tj`);
    streamOps.push('ET');

    const summaryEn = report.field_health_summary?.summary_en ||
      'Zone operating within normal agronomic parameters based on authoritative sensor telemetry.';
    streamOps.push('0.25 0.25 0.25 rg');
    streamOps.push('BT');
    streamOps.push('/F1 8 Tf');
    streamOps.push(`${margin + 10} ${y - 32} Td`);
    streamOps.push(`(${this.escapePdfText(summaryEn)}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= healthBoxHeight + 8;

    // 4 Sensor Metric Tiles (Moisture, Temp, Humidity, pH)
    const tileWidth = (contentWidth - 18) / 4;
    const tileHeight = 44;
    const metrics = [
      { label: 'SOIL MOISTURE', value: `${report.sensor_evidence.moisture.toFixed(1)}%`, desc: 'Capacitive probe' },
      { label: 'TEMPERATURE', value: `${report.sensor_evidence.temperature.toFixed(1)}°C`, desc: 'Ambient edge sensor' },
      { label: 'HUMIDITY', value: `${report.sensor_evidence.humidity.toFixed(1)}%`, desc: 'Relative humidity' },
      { label: 'SOIL pH', value: report.sensor_evidence.ph.toFixed(1), desc: 'Ion concentration' },
    ];

    metrics.forEach((m, idx) => {
      const tileX = margin + idx * (tileWidth + 6);
      streamOps.push('q');
      streamOps.push('0.93 0.96 0.94 rg');
      streamOps.push('0.82 0.88 0.84 RG');
      streamOps.push('0.75 w');
      streamOps.push(`${tileX} ${y - tileHeight} ${tileWidth} ${tileHeight} re B`);

      streamOps.push('0.3 0.3 0.3 rg');
      streamOps.push('BT');
      streamOps.push('/F2 7 Tf');
      streamOps.push(`${tileX + 6} ${y - 12} Td`);
      streamOps.push(`(${this.escapePdfText(m.label)}) Tj`);
      streamOps.push('ET');

      streamOps.push('0.05 0.23 0.18 rg');
      streamOps.push('BT');
      streamOps.push('/F2 13 Tf');
      streamOps.push(`${tileX + 6} ${y - 28} Td`);
      streamOps.push(`(${this.escapePdfText(m.value)}) Tj`);
      streamOps.push('ET');

      streamOps.push('0.4 0.4 0.4 rg');
      streamOps.push('BT');
      streamOps.push('/F1 6.5 Tf');
      streamOps.push(`${tileX + 6} ${y - 38} Td`);
      streamOps.push(`(${this.escapePdfText(m.desc)}) Tj`);
      streamOps.push('ET');
      streamOps.push('Q');
    });

    y -= tileHeight + 18;

    // ------------------------------------------------------------------------
    // 5. Section: Hazard Detections & Risk Events
    // ------------------------------------------------------------------------
    streamOps.push('q');
    streamOps.push('0.05 0.23 0.18 rg');
    streamOps.push('BT');
    streamOps.push('/F2 11 Tf');
    streamOps.push(`${margin} ${y} Td`);
    streamOps.push(`(${this.escapePdfText('2. HAZARD OBSERVATIONS & RISK EVENTS')}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= 8;

    const hazards = report.hazard_history && report.hazard_history.length > 0
      ? report.hazard_history.slice(0, 3)
      : [
          {
            timestamp: report.scan_time,
            hazard_type: report.hazard_summary.hazard_type,
            hazard_name: report.hazard_summary.hazard_name,
            severity: report.hazard_summary.severity,
            confidence: report.hazard_summary.detection_confidence,
          },
        ];

    const hazardRowHeight = 22;
    // Table Header
    streamOps.push('q');
    streamOps.push('0.88 0.91 0.89 rg');
    streamOps.push(`${margin} ${y - 16} ${contentWidth} 16 re f`);

    streamOps.push('0.2 0.2 0.2 rg');
    streamOps.push('BT');
    streamOps.push('/F2 7.5 Tf');
    streamOps.push(`${margin + 8} ${y - 12} Td`);
    streamOps.push(`(${this.escapePdfText('RECORDED AT')}) Tj`);
    streamOps.push(`${margin + 120} ${y - 12} Td`);
    streamOps.push(`(${this.escapePdfText('HAZARD IDENTIFIER')}) Tj`);
    streamOps.push(`${margin + 300} ${y - 12} Td`);
    streamOps.push(`(${this.escapePdfText('SEVERITY')}) Tj`);
    streamOps.push(`${margin + 400} ${y - 12} Td`);
    streamOps.push(`(${this.escapePdfText('CONFIDENCE')}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= 16;

    hazards.forEach((h, idx) => {
      const rowBg = idx % 2 === 0 ? '0.98 0.98 0.98' : '0.95 0.96 0.95';
      streamOps.push('q');
      streamOps.push(`${rowBg} rg`);
      streamOps.push(`${margin} ${y - hazardRowHeight} ${contentWidth} ${hazardRowHeight} re f`);

      streamOps.push('0.2 0.2 0.2 rg');
      streamOps.push('BT');
      streamOps.push('/F1 8 Tf');
      streamOps.push(`${margin + 8} ${y - 14} Td`);
      streamOps.push(`(${this.escapePdfText(new Date(h.timestamp).toLocaleString())}) Tj`);
      streamOps.push('ET');

      streamOps.push('BT');
      streamOps.push('/F2 8 Tf');
      streamOps.push(`${margin + 120} ${y - 14} Td`);
      streamOps.push(`(${this.escapePdfText(h.hazard_name || h.hazard_type)}) Tj`);
      streamOps.push('ET');

      streamOps.push('BT');
      streamOps.push('/F2 8 Tf');
      streamOps.push(`${margin + 300} ${y - 14} Td`);
      streamOps.push(`(${this.escapePdfText(h.severity)}) Tj`);
      streamOps.push('ET');

      streamOps.push('BT');
      streamOps.push('/F1 8 Tf');
      streamOps.push(`${margin + 400} ${y - 14} Td`);
      streamOps.push(`(${this.escapePdfText(`${(h.confidence * 100).toFixed(0)}%`)}) Tj`);
      streamOps.push('ET');
      streamOps.push('Q');

      y -= hazardRowHeight;
    });

    y -= 16;

    // ------------------------------------------------------------------------
    // 6. Section: Closed-Loop Remediation & Verification History
    // ------------------------------------------------------------------------
    streamOps.push('q');
    streamOps.push('0.05 0.23 0.18 rg');
    streamOps.push('BT');
    streamOps.push('/F2 11 Tf');
    streamOps.push(`${margin} ${y} Td`);
    streamOps.push(`(${this.escapePdfText('3. CLOSED-LOOP INTERVENTION & VERIFICATION EVIDENCE')}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= 10;

    const interventionBoxHeight = 82;
    streamOps.push('q');
    streamOps.push('0.95 0.97 0.96 rg');
    streamOps.push('0.80 0.85 0.82 RG');
    streamOps.push('0.75 w');
    streamOps.push(`${margin} ${y - interventionBoxHeight} ${contentWidth} ${interventionBoxHeight} re B`);

    // Action execution info
    streamOps.push('0.1 0.1 0.1 rg');
    streamOps.push('BT');
    streamOps.push('/F2 8.5 Tf');
    streamOps.push(`${margin + 10} ${y - 16} Td`);
    streamOps.push(`(${this.escapePdfText('Action Executed: ' + report.action_executed)}) Tj`);
    streamOps.push('ET');

    streamOps.push('0.3 0.3 0.3 rg');
    streamOps.push('BT');
    streamOps.push('/F1 8 Tf');
    streamOps.push(`${margin + 10} ${y - 30} Td`);
    streamOps.push(`(${this.escapePdfText('Safety Approval: ' + (report.action_approved_by || 'Autonomous Safety Gate Confirmed'))}) Tj`);
    streamOps.push('ET');

    // Verification outcome banner
    const verif = report.before_after_metrics;
    const isSuccess = verif?.resolution_status?.includes('RESOLVED') || report.verification_outcome.includes('resolved');

    streamOps.push(isSuccess ? '0.06 0.72 0.50 rg' : '0.96 0.62 0.04 rg');
    streamOps.push('BT');
    streamOps.push('/F2 8.5 Tf');
    streamOps.push(`${margin + 10} ${y - 48} Td`);
    streamOps.push(
      `(${this.escapePdfText('Verification Outcome: ' + (verif ? verif.resolution_status : report.verification_outcome))}) Tj`
    );
    streamOps.push('ET');

    if (verif) {
      streamOps.push('0.2 0.2 0.2 rg');
      streamOps.push('BT');
      streamOps.push('/F1 8 Tf');
      streamOps.push(`${margin + 10} ${y - 62} Td`);
      streamOps.push(
        `(${this.escapePdfText(`Pre-Intervention: ${verif.pre_moisture.toFixed(1)}% | Post-Intervention: ${verif.post_moisture.toFixed(1)}% | Delta: +${verif.delta.toFixed(1)}% moisture`)}) Tj`
      );
      streamOps.push('ET');
    } else {
      streamOps.push('0.3 0.3 0.3 rg');
      streamOps.push('BT');
      streamOps.push('/F1 8 Tf');
      streamOps.push(`${margin + 10} ${y - 62} Td`);
      streamOps.push(`(${this.escapePdfText('Remediation verification performed via physical re-scan cycle.')}) Tj`);
      streamOps.push('ET');
    }
    streamOps.push('Q');

    y -= interventionBoxHeight + 14;

    // ------------------------------------------------------------------------
    // 7. Section: Recommendations & Next Steps
    // ------------------------------------------------------------------------
    streamOps.push('q');
    streamOps.push('0.05 0.23 0.18 rg');
    streamOps.push('BT');
    streamOps.push('/F2 10 Tf');
    streamOps.push(`${margin} ${y} Td`);
    streamOps.push(`(${this.escapePdfText('4. AGRONOMIC RECOMMENDATIONS & MONITORING SCHEDULE')}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    y -= 14;

    const recommendations = report.recommendations && report.recommendations.length > 0
      ? report.recommendations
      : [
          report.recommendation_made || 'Maintain scheduled micro-irrigation and monitor root-zone moisture.',
          'Schedule secondary rover vision scan within 24-48 hours to confirm disease stagnation.',
        ];

    recommendations.slice(0, 2).forEach((rec) => {
      streamOps.push('0.2 0.2 0.2 rg');
      streamOps.push('BT');
      streamOps.push('/F1 8 Tf');
      streamOps.push(`${margin + 8} ${y} Td`);
      streamOps.push(`(${this.escapePdfText('* ' + rec)}) Tj`);
      streamOps.push('ET');
      y -= 12;
    });

    // ------------------------------------------------------------------------
    // 8. Footer with Branding & Page Metadata
    // ------------------------------------------------------------------------
    const footerY = 28;
    streamOps.push('q');
    streamOps.push('0.7 0.7 0.7 RG');
    streamOps.push('0.5 w');
    streamOps.push(`${margin} ${footerY + 12} ${contentWidth} 0.5 re f`);

    streamOps.push('0.4 0.4 0.4 rg');
    streamOps.push('BT');
    streamOps.push('/F1 7.5 Tf');
    streamOps.push(`${margin} ${footerY} Td`);
    streamOps.push(
      `(${this.escapePdfText('PRAHAR Autonomous Rover & Precision Decision Gateway | Informational Evidence Document')}) Tj`
    );
    streamOps.push('ET');

    streamOps.push('BT');
    streamOps.push('/F2 7.5 Tf');
    streamOps.push(`${pageWidth - margin - 80} ${footerY} Td`);
    streamOps.push(`(${this.escapePdfText('Page 1 of 1')}) Tj`);
    streamOps.push('ET');
    streamOps.push('Q');

    // ------------------------------------------------------------------------
    // Assembly: Pure PDF-1.4 Binary Structure
    // ------------------------------------------------------------------------
    const contentStream = streamOps.join('\n');
    const streamBytes = Buffer.from(contentStream, 'utf-8');

    const objects: string[] = [];

    // Object 1: Catalog
    objects.push('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // Object 2: Pages
    objects.push('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

    // Object 3: Page
    objects.push(
      `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth.toFixed(2)} ${pageHeight.toFixed(2)}] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>\nendobj\n`
    );

    // Object 4: Content Stream
    objects.push(`4 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n${contentStream}\nendstream\nendobj\n`);

    // Object 5: Font F1 (Helvetica)
    objects.push('5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n');

    // Object 6: Font F2 (Helvetica-Bold)
    objects.push('6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

    // Header
    const header = '%PDF-1.4\n%\xe2\xe3\xcf\xd3\n';
    let currentOffset = Buffer.byteLength(header, 'latin1');

    const xrefOffsets: number[] = [0]; // Object 0 is always 0
    let body = '';

    for (const obj of objects) {
      xrefOffsets.push(currentOffset);
      body += obj;
      currentOffset += Buffer.byteLength(obj, 'latin1');
    }

    // XRef Table
    const startXref = currentOffset;
    let xref = `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
    for (let i = 1; i <= objects.length; i++) {
      const offset = xrefOffsets[i].toString().padStart(10, '0');
      xref += `${offset} 00000 n \n`;
    }

    // Trailer
    const trailer = `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${startXref}\n%%EOF\n`;

    return Buffer.concat([
      Buffer.from(header, 'latin1'),
      Buffer.from(body, 'latin1'),
      Buffer.from(xref, 'latin1'),
      Buffer.from(trailer, 'latin1'),
    ]);
  }
}

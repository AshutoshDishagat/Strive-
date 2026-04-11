import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/session.dart';

// ── Shared status colours ─────────────────────────────────────────────────────
const _success = PdfColor.fromInt(0xFF4CAF50);
const _warning = PdfColor.fromInt(0xFFFFAB40);
const _error   = PdfColor.fromInt(0xFFFF5252);

// ── Theme palette ─────────────────────────────────────────────────────────────
class _PdfTheme {
  final PdfColor background;
  final PdfColor surface;
  final PdfColor rowAlt;
  final PdfColor primary;
  final PdfColor textPrimary;
  final PdfColor textSecondary;
  final PdfColor border;

  const _PdfTheme({
    required this.background,
    required this.surface,
    required this.rowAlt,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  // Dark — mirrors AppColors dark mode
  static const dark = _PdfTheme(
    background:    PdfColor.fromInt(0xFF0A191E),
    surface:       PdfColor.fromInt(0xFF14282F),
    rowAlt:        PdfColor.fromInt(0xFF0A191E),
    primary:       PdfColor.fromInt(0xFF00E5FF), // cyan
    textPrimary:   PdfColors.white,
    textSecondary: PdfColor.fromInt(0xFF80959B),
    border:        PdfColor.fromInt(0xFF1E3540),
  );

  // Light — mirrors AppColors light mode
  static const light = _PdfTheme(
    background:    PdfColor.fromInt(0xFFF5F7FA),
    surface:       PdfColors.white,
    rowAlt:        PdfColor.fromInt(0xFFF0F4F8),
    primary:       PdfColor.fromInt(0xFF3F51B5), // indigo
    textPrimary:   PdfColor.fromInt(0xFF2D3436),
    textSecondary: PdfColor.fromInt(0xFF64748B),
    border:        PdfColor.fromInt(0xFFE2E8F0),
  );
}

class ReportsExportService {
  static Future<void> exportAndShare(
    List<Session> sessions,
    String timeframe, {
    bool isDark = true,
  }) async {
    if (sessions.isEmpty) return;

    final t = isDark ? _PdfTheme.dark : _PdfTheme.light;

    // ── Stats ──────────────────────────────────────────────────────────────
    final int totalSeconds =
        sessions.fold(0, (sum, s) => sum + s.durationSeconds);
    final double avgScore =
        (sessions.fold(0.0, (sum, s) => sum + s.engagementScore) /
                sessions.length) *
            100;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: t.background),
          ),
        ),
        build: (pw.Context ctx) => [

          // ── Header ────────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
            decoration: pw.BoxDecoration(
              color: t.surface,
              border: pw.Border(
                bottom: pw.BorderSide(color: t.primary, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STRIVE',
                      style: pw.TextStyle(
                        color: t.primary,
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Study Performance Report',
                      style: pw.TextStyle(color: t.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _badge(timeframe.toUpperCase(), t),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _formatExportDate(DateTime.now()),
                      style: pw.TextStyle(color: t.textSecondary, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── Stat cards ────────────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.Row(
              children: [
                _statCard('Total Study Time', _formatDuration(totalSeconds), t),
                pw.SizedBox(width: 12),
                _statCard('Avg Focus Score', '${avgScore.toStringAsFixed(1)}%', t),
                pw.SizedBox(width: 12),
                _statCard('Total Sessions', '${sessions.length}', t),
              ],
            ),
          ),

          pw.SizedBox(height: 28),

          // ── Section title ─────────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.Row(
              children: [
                pw.Container(width: 3, height: 14, color: t.primary),
                pw.SizedBox(width: 8),
                pw.Text(
                  'SESSION RECORDS',
                  style: pw.TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // ── Table ─────────────────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.0),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: t.surface),
                  children: ['DATE & TIME', 'MODE', 'DURATION', 'FOCUS']
                      .map((h) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                    color: t.primary, width: 1.5),
                              ),
                            ),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                color: t.primary,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                // Data rows
                ...sessions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final rowBg = i.isOdd ? t.surface : t.rowAlt;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      _tableCell(_formatCellDate(s.startTime), t.textPrimary),
                      _tableCell(_formatMode(s.studyMode), t.textSecondary),
                      _tableCell(_formatDuration(s.durationSeconds), t.textPrimary),
                      _focusCell(s.engagementScore),
                    ],
                  );
                }),
              ],
            ),
          ),

          pw.SizedBox(height: 40),

          // ── Footer ────────────────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.Container(
              padding: const pw.EdgeInsets.only(top: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: t.border, width: 1),
                ),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Generated by Strive AI  ·  Keep striving ✦',
                  style: pw.TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // ── Save & share ──────────────────────────────────────────────────────
    final dir = await getTemporaryDirectory();
    final theme = isDark ? 'Dark' : 'Light';
    final fileName =
        'Strive_Report_${timeframe}_${theme}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'My Strive Study Report ($timeframe)',
        text: 'Study Report from Strive AI 🎓',
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  static pw.Widget _badge(String text, _PdfTheme t) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: t.primary,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: t.background,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  static pw.Widget _statCard(String label, String value, _PdfTheme t) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: t.surface,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: t.border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(color: t.textSecondary, fontSize: 8)),
            pw.SizedBox(height: 6),
            pw.Text(value,
                style: pw.TextStyle(
                  color: t.primary,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(text, style: pw.TextStyle(color: color, fontSize: 9)),
    );
  }

  static pw.Widget _focusCell(double score) {
    final PdfColor color;
    if (score >= 0.75) {
      color = _success;
    } else if (score >= 0.45) {
      color = _warning;
    } else {
      color = _error;
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        '${(score * 100).toStringAsFixed(0)}%',
        style: pw.TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // ── String helpers ─────────────────────────────────────────────────────────

  static String _formatMode(String? mode) {
    switch (mode) {
      case 'readingBook': return 'Book';
      case 'phoneScreen': return 'Screen';
      case 'mix':         return 'Mix';
      default:            return 'Focus';
    }
  }

  static String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${totalSeconds % 60}s';
  }

  static String _formatCellDate(String isoString) {
    try {
      final d = DateTime.parse(isoString);
      return '${d.day}/${d.month}/${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString.split('T').first;
    }
  }

  static String _formatExportDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

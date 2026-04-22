import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:strive1/core/theme/colors.dart';
import 'package:strive1/models/session.dart';

// ── Study Time Bar Chart ─────────────────────────────────────────────
class StudyTimeBarChart extends StatelessWidget {
  final List<Session> sessions;
  final String filter; // Daily, Weekly, Monthly

  const StudyTimeBarChart({
    super.key,
    required this.sessions,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final data = _buildBarData();
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'STUDY TIME',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppColors.surface.withAlpha(240),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final minutes = rod.toY.toInt();
                      final label = data[group.x.toInt()].label;
                      return BarTooltipItem(
                        '$label\n',
                        TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: '${minutes}m',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${value.toInt()}m',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[idx].shortLabel,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value,
                        width: data.length > 10 ? 10 : 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary.withAlpha(120),
                            AppColors.primary,
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  List<_ChartPoint> _buildBarData() {
    if (sessions.isEmpty) return [];

    final Map<String, double> grouped = {};
    final Map<String, String> shortLabels = {};
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final session in sessions) {
      final date = DateTime.tryParse(session.startTime);
      if (date == null) continue;
      final minutes = session.durationSeconds / 60.0;

      String key;
      String short;

      if (filter == 'Daily') {
        key = '${date.day}/${date.month}';
        short = '${date.day}/${date.month}';
      } else if (filter == 'Weekly') {
        key = '${date.day}/${date.month}';
        short = weekdays[date.weekday - 1];
      } else {
        key = '${months[date.month - 1]} ${date.year}';
        short = months[date.month - 1];
      }

      grouped[key] = (grouped[key] ?? 0) + minutes;
      shortLabels[key] = short;
    }

    final entries = grouped.entries.toList();
    // Show last 7 entries max for readability
    final display =
        entries.length > 7 ? entries.sublist(entries.length - 7) : entries;

    return display
        .map((e) => _ChartPoint(
              label: e.key,
              shortLabel: shortLabels[e.key] ?? e.key,
              value: double.parse(e.value.toStringAsFixed(1)),
            ))
        .toList();
  }
}

// ── Engagement Line Chart ────────────────────────────────────────────
class EngagementLineChart extends StatelessWidget {
  final List<Session> sessions;
  final String filter;

  const EngagementLineChart({
    super.key,
    required this.sessions,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final data = _buildLineData();
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.show_chart_rounded,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'FOCUS TREND',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppColors.surface.withAlpha(240),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final label =
                            idx < data.length ? data[idx].label : '';
                        return LineTooltipItem(
                          '$label\n',
                          TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text: '${spot.y.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        // Show every other label if too many
                        if (data.length > 5 && idx % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[idx].shortLabel,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.value);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.accent,
                          strokeWidth: 2,
                          strokeColor: AppColors.card,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withAlpha(60),
                          AppColors.accent.withAlpha(5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  List<_ChartPoint> _buildLineData() {
    if (sessions.isEmpty) return [];

    final Map<String, List<double>> grouped = {};
    final Map<String, String> shortLabels = {};
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final session in sessions) {
      final date = DateTime.tryParse(session.startTime);
      if (date == null) continue;
      final score = session.engagementScore * 100;

      String key;
      String short;

      if (filter == 'Daily') {
        key = '${date.day}/${date.month}';
        short = '${date.day}/${date.month}';
      } else if (filter == 'Weekly') {
        key = '${date.day}/${date.month}';
        short = weekdays[date.weekday - 1];
      } else {
        key = '${months[date.month - 1]} ${date.year}';
        short = months[date.month - 1];
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(score);
      shortLabels[key] = short;
    }

    final entries = grouped.entries.toList();
    final display =
        entries.length > 10 ? entries.sublist(entries.length - 10) : entries;

    return display.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return _ChartPoint(
        label: e.key,
        shortLabel: shortLabels[e.key] ?? e.key,
        value: double.parse(avg.toStringAsFixed(1)),
      );
    }).toList();
  }
}

// ── Study Mode Distribution Pie Chart ────────────────────────────────
class StudyModeChart extends StatelessWidget {
  final List<Session> sessions;

  const StudyModeChart({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final data = _buildPieData();
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.pie_chart_rounded,
                    color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'STUDY MODES',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 30,
                    sections: data.map((d) {
                      return PieChartSectionData(
                        value: d.value,
                        color: d.color,
                        radius: 40,
                        title: '${d.value.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.map((d) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: d.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.label,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${d.value.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_PieSlice> _buildPieData() {
    if (sessions.isEmpty) return [];

    final Map<String, int> counts = {};
    for (final s in sessions) {
      final mode = s.studyMode ?? 'focus';
      counts[mode] = (counts[mode] ?? 0) + 1;
    }

    final total = sessions.length;
    final colors = {
      'readingBook': const Color(0xFF66BB6A),
      'phoneScreen': const Color(0xFF42A5F5),
      'mix': const Color(0xFFAB47BC),
      'strictBook': const Color(0xFFFF7043),
      'aiTutor': const Color(0xFFFFCA28),
      'focus': AppColors.primary,
    };

    final labels = {
      'readingBook': 'Book Reading',
      'phoneScreen': 'Phone Screen',
      'mix': 'Mixed Mode',
      'strictBook': 'Strict Book',
      'aiTutor': 'AI Tutor',
      'focus': 'Focus',
    };

    return counts.entries.map((e) {
      final pct = (e.value / total) * 100;
      return _PieSlice(
        label: labels[e.key] ?? e.key,
        value: pct,
        color: colors[e.key] ?? AppColors.primary,
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }
}

// ── Data models ──────────────────────────────────────────────────────
class _ChartPoint {
  final String label;
  final String shortLabel;
  final double value;

  const _ChartPoint({
    required this.label,
    required this.shortLabel,
    required this.value,
  });
}

class _PieSlice {
  final String label;
  final double value;
  final Color color;

  const _PieSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

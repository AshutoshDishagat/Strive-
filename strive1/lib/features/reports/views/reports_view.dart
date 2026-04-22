import 'package:flutter/material.dart';
import 'package:strive1/core/theme/colors.dart';
import 'package:strive1/core/db/database_helper.dart';
import 'package:strive1/core/services/firestore_service.dart';
import 'package:strive1/models/session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strive1/core/widgets/glass_error_banner.dart';
import 'package:strive1/core/theme/theme_controller.dart';
import '../services/reports_export_service.dart';
import '../widgets/study_charts.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  bool _isLoading = true;
  List<Session> _sessions = [];
  String? _errorMessage;
  String _selectedFilter = 'Daily';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Load from local SQLite first
      final localSessions = await DatabaseHelper.instance.getSessions(user?.uid);

      // Also load from Firestore (sessions from other devices / remote starts)
      List<Session> firestoreSessions = [];
      if (user != null) {
        try {
          firestoreSessions = await FirestoreService().getSessions();
        } catch (_) {
          // Firestore unavailable — local data is enough
        }
      }

      // Merge: prefer local, add Firestore ones not already in local (dedup by startTime)
      final localKeys = localSessions.map((s) => s.startTime).toSet();
      final merged = [
        ...localSessions,
        ...firestoreSessions.where((s) => !localKeys.contains(s.startTime)),
      ];
      merged.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (mounted) {
        setState(() {
          _sessions = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load reports: ${e.toString().split('\n')[0]}";
        });
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return isoString.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'STUDY REPORTS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildTimeframeSelector(),
        ),
      ),
      floatingActionButton: SizedBox(
        height: 40,
        child: FloatingActionButton.extended(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (_sessions.isEmpty) {
              messenger.showSnackBar(
                const SnackBar(content: Text("No records to export yet! 📊")),
              );
              return;
            }

            try {
              await ReportsExportService.exportAndShare(_sessions, _selectedFilter);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text("Report Created & Sharing... 📄")),
              );
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text("Export failed: ${e.toString().split('\n')[0]}")),
              );
            }
          },
          backgroundColor: AppColors.primary,
          elevation: 4,
          icon: const Icon(Icons.share_rounded, color: Colors.black, size: 18),
          label: const Text("REPORT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 8.0),
                    child: GlassErrorBanner(
                      message: _errorMessage!,
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _sessions.isEmpty
                    ? _buildEmptyState()
                    : _buildContentWithCharts(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final filters = ['Daily', 'Weekly', 'Monthly'];
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  filter.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 80, color: AppColors.primary.withAlpha(25)),
          const SizedBox(height: 16),
          Text(
            "No Records Yet",
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Complete a deep work session to see your stats.",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContentWithCharts() {
    Map<String, List<Session>> grouped = {};

    for (var session in _sessions) {
      final date = DateTime.parse(session.startTime);
      String key;

      if (_selectedFilter == 'Daily') {
        key = _formatDate(session.startTime);
      } else if (_selectedFilter == 'Weekly') {
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        key = "Week: ${_formatDate(startOfWeek.toIso8601String())} - ${_formatDate(endOfWeek.toIso8601String())}";
      } else {
        // Monthly
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        key = "${months[date.month - 1]} ${date.year}";
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(session);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // ── Charts Section ──
        StudyTimeBarChart(
          sessions: _sessions,
          filter: _selectedFilter,
        ),
        EngagementLineChart(
          sessions: _sessions,
          filter: _selectedFilter,
        ),
        StudyModeChart(sessions: _sessions),
        const SizedBox(height: 8),
        // ── Sessions Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'SESSION HISTORY',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── Grouped Session Cards ──
        ...grouped.entries.toList().asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _TimeframeReportCard(
              title: entry.value.key,
              sessions: entry.value.value,
              initiallyExpanded: entry.key == 0,
            ),
          );
        }),
      ],
    );
  }
}

class _TimeframeReportCard extends StatefulWidget {
  final String title;
  final List<Session> sessions;
  final bool initiallyExpanded;

  const _TimeframeReportCard({
    required this.title,
    required this.sessions,
    this.initiallyExpanded = false,
  });

  @override
  State<_TimeframeReportCard> createState() => _TimeframeReportCardState();
}

class _TimeframeReportCardState extends State<_TimeframeReportCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return "${hours}h ${minutes}m";
    return "${minutes}m ${totalSeconds % 60}s";
  }

  String _formatTime(String isoString) {
    try {
      final d = DateTime.parse(isoString);
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final m = d.minute.toString().padLeft(2, '0');
      final p = d.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalSeconds =
        widget.sessions.fold<int>(0, (sum, item) => sum + item.durationSeconds);
    double totalScore =
        widget.sessions.fold<double>(0.0, (sum, item) => sum + item.engagementScore);
    double avgScore = widget.sessions.isEmpty
        ? 0
        : (totalScore / widget.sessions.length) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: ThemeController.instance.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${widget.sessions.length} Sessions",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatMini(
                    "Time", _formatDuration(totalSeconds), Icons.timer),
              ),
              Expanded(
                child: _buildStatMini(
                    "Focus", "${avgScore.toStringAsFixed(0)}%", Icons.bolt),
              ),
            ],
          ),
          if (_isExpanded && widget.sessions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text("SESSIONS",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            ...widget.sessions.map((s) => _buildSessionCard(s)),
          ]
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    IconData modeIcon;
    String modeLabel;

    switch (session.studyMode) {
      case 'readingBook':
        modeIcon = Icons.menu_book;
        modeLabel = "Book";
        break;
      case 'phoneScreen':
        modeIcon = Icons.smartphone;
        modeLabel = "Screen";
        break;
      case 'mix':
        modeIcon = Icons.auto_awesome_mosaic;
        modeLabel = "Mix";
        break;
      default:
        modeIcon = Icons.center_focus_strong;
        modeLabel = "Focus";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(modeIcon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modeLabel,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(
                    "${(session.engagementScore * 100).toStringAsFixed(0)}% Focus • ${_formatTime(session.startTime)}",
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            _formatDuration(session.durationSeconds),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMini(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            Text(value,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:strive1/core/db/database_helper.dart';
import 'package:strive1/core/services/firestore_service.dart';
import 'package:strive1/models/session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strive1/core/widgets/glass_error_banner.dart';
import '../services/reports_export_service.dart';
import '../widgets/study_charts.dart';

class ReportsView extends StatefulWidget {
  final bool isKidsMode;
  const ReportsView({super.key, this.isKidsMode = false});

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
      final localSessions = await DatabaseHelper.instance.getSessions(user?.uid);

      List<Session> firestoreSessions = [];
      if (user != null) {
        try {
          firestoreSessions = await FirestoreService().getSessions();
        } catch (_) {}
      }

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isKidsMode ? 'MY PROGRESS 🏆' : 'STUDY REPORTS',
          style: tt.titleMedium?.copyWith(
            fontSize: widget.isKidsMode ? 18 : 16,
            fontWeight: FontWeight.w900,
            letterSpacing: widget.isKidsMode ? 1.5 : 1.2,
            color: cs.primary, 
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildTimeframeSelector(context),
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
              await ReportsExportService.exportAndShare(
                  _sessions, _selectedFilter);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                    content: Text("Report Created & Sharing... 📄")),
              );
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                    content: Text(
                        "Export failed: ${e.toString().split('\n')[0]}")),
              );
            }
          },
          backgroundColor: cs.primary,
          elevation: 4,
          icon: Icon(Icons.share_rounded,
              color: cs.onPrimary, size: 18),
          label: Text("REPORT",
              style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10)),
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
                    child: CircularProgressIndicator(color: cs.primary))
                : _sessions.isEmpty
                    ? _buildEmptyState(context)
                    : _buildContentWithCharts(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.primary.withAlpha(50),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  filter.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? cs.onPrimary : cs.onSurface.withAlpha(160),
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

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 80, color: cs.primary.withAlpha(60)),
          const SizedBox(height: 16),
          Text("No Records Yet",
              style: tt.titleLarge?.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            "Complete a deep work session to see your stats.",
            style: tt.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContentWithCharts(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Map<String, List<Session>> grouped = {};

    for (var session in _sessions) {
      final date = DateTime.parse(session.startTime);
      String key;

      if (_selectedFilter == 'Daily') {
        key = _formatDate(session.startTime);
      } else if (_selectedFilter == 'Weekly') {
        final startOfWeek =
            date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        key =
            "Week: ${_formatDate(startOfWeek.toIso8601String())} - ${_formatDate(endOfWeek.toIso8601String())}";
      } else {
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
        StudyTimeBarChart(sessions: _sessions, filter: _selectedFilter),
        EngagementLineChart(sessions: _sessions, filter: _selectedFilter),
        StudyModeChart(sessions: _sessions),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'SESSION HISTORY',
            style: tt.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: cs.onSurface.withAlpha(130),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    int totalSeconds = widget.sessions
        .fold<int>(0, (sum, item) => sum + item.durationSeconds);
    double totalScore = widget.sessions
        .fold<double>(0.0, (sum, item) => sum + item.engagementScore);
    double avgScore = widget.sessions.isEmpty
        ? 0
        : (totalScore / widget.sessions.length) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withAlpha(40)),
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
                  style: tt.titleMedium?.copyWith(fontSize: 15),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${widget.sessions.length} Sessions",
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: cs.primary.withAlpha(50)),
                        ),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: cs.onSurface.withAlpha(130),
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
                child: _buildStatMini(context, "Time",
                    _formatDuration(totalSeconds), Icons.timer),
              ),
              Expanded(
                child: _buildStatMini(context, "Focus",
                    "${avgScore.toStringAsFixed(0)}%", Icons.bolt),
              ),
            ],
          ),
          if (_isExpanded && widget.sessions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text("SESSIONS",
                style: tt.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: cs.onSurface.withAlpha(130),
                )),
            const SizedBox(height: 12),
            ...widget.sessions.map((s) => _buildSessionCard(context, s)),
          ]
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Session session) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
        color: cs.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(modeIcon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modeLabel,
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                    "${(session.engagementScore * 100).toStringAsFixed(0)}% Focus • ${_formatTime(session.startTime)}",
                    style: tt.bodySmall),
              ],
            ),
          ),
          Text(
            _formatDuration(session.durationSeconds),
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMini(
      BuildContext context, String label, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, color: cs.onSurface.withAlpha(130), size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tt.bodySmall),
            Text(value,
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}

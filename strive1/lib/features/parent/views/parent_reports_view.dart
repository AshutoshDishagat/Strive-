import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/session.dart';
import '../../reports/widgets/study_charts.dart';

class ParentReportsView extends StatefulWidget {
  final String studentId;
  final String studentEmail;
  final bool isTab;

  const ParentReportsView({
    super.key,
    required this.studentId,
    required this.studentEmail,
    this.isTab = false,
  });

  @override
  State<ParentReportsView> createState() => _ParentReportsViewState();
}

class _ParentReportsViewState extends State<ParentReportsView> {
  final _firestoreService = FirestoreService();

  bool _isLoading = true;
  List<Session> _sessions = [];
  String _selectedFilter = 'Daily';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions =
        await _firestoreService.getStudentSessions(widget.studentId);
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoString.split('T').first;
    }
  }

  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${totalSeconds % 60}s';
  }

  Map<String, List<Session>> _grouped() {
    final grouped = <String, List<Session>>{};
    for (var s in _sessions) {
      String key;
      final date = DateTime.parse(s.startTime);
      if (_selectedFilter == 'Daily') {
        key = _formatDate(s.startTime);
      } else if (_selectedFilter == 'Weekly') {
        final start = date.subtract(Duration(days: date.weekday - 1));
        final end = start.add(const Duration(days: 6));
        key =
            'Week: ${_formatDate(start.toIso8601String())} – ${_formatDate(end.toIso8601String())}';
      } else {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        key = '${months[date.month - 1]} ${date.year}';
      }
      grouped.putIfAbsent(key, () => []).add(s);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _sessions.isEmpty
            ? _buildEmpty()
            : _buildList();

    if (widget.isTab) {
      return Column(
        children: [
          _buildFilter(),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STUDY REPORTS',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              widget.studentEmail,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildFilter(),
        ),
      ),
      body: content,
    );
  }

  Widget _buildFilter() {
    final filters = ['Daily', 'Weekly', 'Monthly'];
    return Container(
      height: 52,
      padding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: filters.map((f) {
          final active = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  f.toUpperCase(),
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 72, color: AppColors.primary.withAlpha(30)),
          const SizedBox(height: 16),
          Text('No Sessions Yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Your student hasn\'t completed a session yet.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = _grouped();
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
          final title = entry.value.key;
          final sessions = entry.value.value;
          final totalSec =
              sessions.fold<int>(0, (s, e) => s + e.durationSeconds);
          final avgFocus = sessions.isEmpty
              ? 0.0
              : sessions.fold<double>(
                      0.0, (s, e) => s + e.engagementScore) /
                  sessions.length *
                  100;

          return Container(
            margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
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
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sessions.length} Sessions',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statMini(Icons.timer_rounded, 'Time',
                        _formatDuration(totalSec)),
                    const SizedBox(width: 32),
                    _statMini(Icons.bolt_rounded, 'Avg Focus',
                        '${avgFocus.toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 16),
                ...sessions.map((s) => _sessionRow(s)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statMini(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
            Text(value,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _sessionRow(Session session) {
    IconData modeIcon;
    String modeLabel;
    switch (session.studyMode) {
      case 'readingBook':
        modeIcon = Icons.menu_book;
        modeLabel = 'Book';
        break;
      case 'phoneScreen':
        modeIcon = Icons.smartphone;
        modeLabel = 'Screen';
        break;
      case 'mix':
        modeIcon = Icons.auto_awesome_mosaic;
        modeLabel = 'Mix';
        break;
      default:
        modeIcon = Icons.center_focus_strong;
        modeLabel = 'Focus';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(modeIcon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modeLabel,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(
                  '${(session.engagementScore * 100).toStringAsFixed(0)}% Focus',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(session.durationSeconds),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class DNDSelectView extends StatefulWidget {
  final Set<String> initialAllowedApps;
  final Function(Set<String>) onSave;

  /// When true, shows a "LOCK & START SESSION" button at the bottom
  /// and the screen title changes to "Focus Lock".
  final bool showStartButton;

  const DNDSelectView({
    super.key,
    required this.initialAllowedApps,
    required this.onSave,
    this.showStartButton = false,
  });

  @override
  State<DNDSelectView> createState() => _DNDSelectViewState();
}

class _DNDSelectViewState extends State<DNDSelectView> {
  late Set<String> _allowedApps;
  List<AppInfo> _installedApps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allowedApps = Set.from(widget.initialAllowedApps);
    _loadApps();
  }

  Future<void> _loadApps() async {
    List<AppInfo> apps = await InstalledApps.getInstalledApps(
      withIcon: true,
      excludeSystemApps: false,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  void _filterApps(String query) {
    setState(() {
      _filteredApps = _installedApps
          .where((app) =>
              app.name.toLowerCase().contains(query.toLowerCase()) ||
              app.packageName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _save() {
    widget.onSave(_allowedApps);
    Navigator.pop(context, _allowedApps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            if (widget.showStartButton) ...[
              Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              widget.showStartButton ? "Focus Lock" : "Allowed Apps",
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, null), // null = cancelled
        ),
        actions: [
          if (!widget.showStartButton)
            TextButton(
              onPressed: _save,
              child: Text("SAVE",
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner when in start-session mode
          if (widget.showStartButton)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All apps will be blocked. Toggle ON the ones you still want to access during your session.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: _filterApps,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "Search apps...",
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Selected count badge
          if (_allowedApps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withAlpha(80)),
                    ),
                    child: Text(
                      '${_allowedApps.length} app${_allowedApps.length == 1 ? '' : 's'} allowed',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _allowedApps.clear()),
                    child: Text('Clear all',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ),
                ],
              ),
            ),

          // App list
          if (_isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredApps.length,
                itemBuilder: (context, index) {
                  final app = _filteredApps[index];
                  final packageName = app.packageName;
                  final isAllowed = _allowedApps.contains(packageName);

                  return ListTile(
                    leading: app.icon != null
                        ? Image.memory(app.icon!, width: 40)
                        : Icon(Icons.android, color: AppColors.textSecondary),
                    title: Text(app.name,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(packageName,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                    trailing: Switch(
                      value: isAllowed,
                      thumbColor:
                          WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return null;
                      }),
                      trackColor:
                          WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary.withAlpha(50);
                        }
                        return null;
                      }),
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            _allowedApps.add(packageName);
                          } else {
                            _allowedApps.remove(packageName);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),

          // LOCK & START button (only in start mode)
          if (widget.showStartButton)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded,
                              color: AppColors.background, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'LOCK & START SESSION',
                            style: TextStyle(
                              color: AppColors.background,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context, <String>{}),
                      child: Text(
                        'Start without App Lock',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

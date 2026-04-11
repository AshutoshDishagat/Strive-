import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/user_profile.dart';

class LinkedGuardianView extends StatefulWidget {
  const LinkedGuardianView({super.key});

  @override
  State<LinkedGuardianView> createState() => _LinkedGuardianViewState();
}

class _LinkedGuardianViewState extends State<LinkedGuardianView> {
  bool _isLoading = true;
  Map<String, dynamic>? _guardianInfo;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadGuardian();
  }

  Future<void> _loadGuardian() async {
    setState(() => _isLoading = true);
    try {
      final data = await _firestoreService.getGuardian();
      if (mounted) {
        setState(() {
          _guardianInfo = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load guardian data: $e')),
        );
      }
    }
  }


  Future<void> _unlinkGuardian() async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.removeGuardian();
      await _loadGuardian();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to unlink: $e")),
        );
      }
    }
  }

  void _showAddGuardianSheet() {
    _nameController.clear();
    _emailController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          bool isSaving = false;

          Future<void> onLinkTapped() async {
            if (_nameController.text.trim().isEmpty ||
                _emailController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill in both fields.")),
              );
              return;
            }

            setSheetState(() => isSaving = true);
            try {
              await _firestoreService.setGuardian(
                _nameController.text.trim(),
                _emailController.text.trim(),
              );
              
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop(); // Close sheet
              }
              if (mounted) {
                await _loadGuardian();       // Refresh parent state
              }
            } catch (e) {
              setSheetState(() => isSaving = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to link guardian: $e")),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Link Guardian Account",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your guardian will be able to see your synced study reports on their Companion App.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Guardian's Name",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Guardian's Email",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.email, color: AppColors.primary),
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isSaving ? null : onLinkTapped,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withAlpha(100),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          "Link Account",
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: _guardianInfo == null
                              ? _buildUnlinkedState()
                              : _buildLinkedState(),
                        ),
                        _buildSwitchRoleButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRoleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextButton.icon(
        onPressed: () async {
          setState(() => _isLoading = true);
          await _firestoreService.setUserRole(UserRole.parent);
          // Navigate to parent app automatically because of AuthWrapper StreamBuilder
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        },
        icon: Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
        label: Text(
          "Switch to Parent Companion",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "Guardian Account",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlinkedState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.family_restroom,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "No Guardian Linked",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Link a parent or guardian's email to automatically share your study reports and help stay accountable.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _showAddGuardianSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Add Guardian",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withAlpha(50)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(10),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withAlpha(40),
                  child: Icon(Icons.person, color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _guardianInfo?['name'] ?? 'Unknown Name',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _guardianInfo?['email'] ?? 'Unknown Email',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.sync_rounded, color: AppColors.primary),
            title: Text(
              "Reports are syncing",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              "Your guardian will see updates securely.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text("Disconnect Guardian?",
                      style: TextStyle(color: AppColors.textPrimary)),
                  content: Text(
                    "This will stop syncing your reports and remove their access.",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _unlinkGuardian();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Disconnect",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Remove Access",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

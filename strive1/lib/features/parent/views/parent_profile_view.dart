import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/user_profile.dart';
import 'link_student_view.dart';

class ParentProfileView extends StatefulWidget {
  const ParentProfileView({super.key});

  @override
  State<ParentProfileView> createState() => _ParentProfileViewState();
}

class _ParentProfileViewState extends State<ParentProfileView> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Parent';
    final email = user?.email ?? 'No Email';
    final photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=$displayName&background=00e5ff&color=0f2123&size=200';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Header
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 4),
                    image: DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              email,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Settings Sections
            _buildSectionHeader('ACCOUNT SETTINGS'),
            _buildListTile(Icons.person_outline, 'Personal Information'),
            _buildListTile(Icons.link_rounded, 'Link Student Account',
                onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LinkStudentView()),
              );
            }),
            _buildListTile(Icons.security_rounded, 'Security & Privacy'),
            _buildListTile(
              Icons.swap_horiz_rounded,
              'Switch to Student Mode',
              onTap: () async {
                final fs = FirestoreService();
                await fs.setUserRole(UserRole.student);
              },
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader('APP PREFERENCES'),
            _buildThemeToggle(),
            _buildListTile(Icons.notifications_none_rounded, 'Notifications'),
            
            const SizedBox(height: 24),
            _buildSectionHeader('DANGER ZONE'),
            _buildSignOutTile(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.dark_mode_rounded, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Dark Mode',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: ThemeController.instance.isDarkMode,
              onChanged: (val) {
                ThemeController.instance.toggleTheme();
                setState(() {});
              },
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutTile() {
    return GestureDetector(
      onTap: () => _authService.signOut(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 16),
            Text(
              'Sign Out',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

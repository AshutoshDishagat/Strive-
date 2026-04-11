import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/widgets/glass_error_banner.dart';
import '../../../models/user_profile.dart';
import 'register_view.dart';
import 'forgot_password_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  UserRole _selectedRole = UserRole.student; // default

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill out all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _authService.signInWithEmail(email, password);
      if (cred?.user != null) {
        await _authService.ensureProfileExists(cred!.user!, _selectedRole);
        // Persist role locally on this device
        await _authService.saveLocalRole(_selectedRole);
        // Always apply the role the user selected on this login screen
        try {
          await _firestoreService.setUserRole(_selectedRole);
        } catch (_) {
          // Non-fatal: app will still navigate, role will sync on next launch
        }
      }
      // StreamBuilder handles navigation
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _parseAuthError(e.toString());
        });
      }
    }
  }

  String _parseAuthError(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    if (error.contains('wrong-password')) {
      return 'Incorrect password.';
    }
    if (error.contains('invalid-email')) {
      return 'Please enter a valid email.';
    }
    if (error.contains('user-disabled')) {
      return 'This account has been disabled.';
    }
    return error.replaceAll(RegExp(r'\[.*\]'), '').trim();
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred?.user != null) {
        await _authService.ensureProfileExists(cred!.user!, _selectedRole);
        // Persist role locally on this device
        await _authService.saveLocalRole(_selectedRole);
        // Always apply the role the user selected on this login screen
        try {
          await _firestoreService.setUserRole(_selectedRole);
        } catch (_) {
          // Non-fatal: app will still navigate, role will sync on next launch
        }
      }
      if (cred == null && mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google Sign-In Failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTitleSection(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: _buildErrorBanner(),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              _buildRoleSelector(),
              const SizedBox(height: 24),
              _buildForm(),
              const SizedBox(height: 32),
              _buildLoginButton(),
              const SizedBox(height: 16),
              _buildRegisterOption(),
              const SizedBox(height: 32),
              _buildDivider(),
              const SizedBox(height: 32),
              _buildGoogleLoginButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return GlassErrorBanner(
      message: _errorMessage!,
      onDismiss: () => setState(() => _errorMessage = null),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I AM A...',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: ThemeController.instance.isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Row(
            children: [
              _buildRoleTab(
                label: 'Student',
                icon: Icons.school_rounded,
                isActive: _selectedRole == UserRole.student,
                onTap: () => setState(() => _selectedRole = UserRole.student),
              ),
              _buildRoleTab(
                label: 'Parent',
                icon: Icons.supervisor_account_rounded,
                isActive: _selectedRole == UserRole.parent,
                onTap: () => setState(() => _selectedRole = UserRole.parent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          "Strive | Secure Access",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withAlpha(40)),
          ),
          child: Icon(
            Icons.psychology,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Unlock Focus",
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your journey to deep work starts here.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: "Email Address",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          label: "Password",
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: !_isPasswordVisible,
          onTogglePassword: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: _buildForgotPasswordLink(),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: ThemeController.instance.isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: "Enter your $label",
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withAlpha(100), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordLink() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForgotPasswordView()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
        child: Text(
          "Forgot Password?",
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterOption() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLoading
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterView()),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Text(
              "Register",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLoading ? null : _loginWithEmail,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(80),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  "SIGN IN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "OR SECURELY USE",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildGoogleLoginButton() {
    return InkWell(
      onTap: _isLoading ? null : _loginWithGoogle,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: ThemeController.instance.isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withAlpha(ThemeController.instance.isDarkMode ? 40 : 20),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Icon(Icons.g_mobiledata_rounded,
                      color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Continue with Google",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Fast & secure access",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}

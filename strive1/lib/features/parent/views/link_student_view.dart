import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/firestore_service.dart';

class LinkStudentView extends StatefulWidget {
  const LinkStudentView({super.key});

  @override
  State<LinkStudentView> createState() => _LinkStudentViewState();
}

class _LinkStudentViewState extends State<LinkStudentView> {
  final _emailController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _linkStudent() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = "Please enter the student's email.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final studentUid = await _firestoreService.findStudentByEmail(email);
      if (studentUid == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No student account found with this email.\nMake sure your child has registered as a Student.';
        });
        return;
      }

      await _firestoreService.linkParentToStudent(studentUid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Student linked successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains("registered as a Parent account")) {
          _errorMessage = "This email is registered as a Parent. Please verify your child's student email.";
        } else {
          _errorMessage = 'Something went wrong. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Link a Student',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.supervisor_account_rounded,
                        color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connect Your Child\'s Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the email your child used when registering as a Student on Strive.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Email field label
            Text(
              'STUDENT EMAIL',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
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
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.alternate_email_rounded,
                      color: AppColors.primary, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  hintText: 'e.g. student@gmail.com',
                  hintStyle: TextStyle(
                      color: AppColors.textSecondary.withAlpha(100),
                      fontSize: 14),
                ),
              ),
            ),

            // Error
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style:
                            TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Link button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isLoading ? null : _linkStudent,
              child: Container(
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
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'LINK STUDENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

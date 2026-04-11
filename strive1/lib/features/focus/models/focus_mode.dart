import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import 'study_mode.dart';

class FocusMode {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final StudyMode studyMode;
  final bool isCameraRequired;

  const FocusMode({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.studyMode,
    this.isCameraRequired = true,
  });

  static List<FocusMode> predefinedModes = [
    FocusMode(
      id: 'reading',
      title: 'Reading Book',
      icon: Icons.menu_book_rounded,
      color: AppColors.primary,
      studyMode: StudyMode.readingBook,
    ),
    FocusMode(
      id: 'phone',
      title: 'Phone Study',
      icon: Icons.smartphone_rounded,
      color: AppColors.accent,
      studyMode: StudyMode.phoneScreen,
    ),
    const FocusMode(
      id: 'mix',
      title: 'Mix Mode',
      icon: Icons.all_inclusive_rounded,
      color: Colors.purple,
      studyMode: StudyMode.mix,
    ),
    const FocusMode(
      id: 'strict',
      title: 'Smart Book',
      icon: Icons.document_scanner_rounded,
      color: Colors.orange,
      studyMode: StudyMode.strictBook,
    ),
    const FocusMode(
      id: 'ai',
      title: 'AI Tutor',
      icon: Icons.auto_awesome,
      color: Colors.blueAccent,
      studyMode: StudyMode.aiTutor,
      isCameraRequired: false,
    ),
  ];
}

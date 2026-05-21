/// Roles in the app.
enum UserRole { student, parent }

class UserProfile {
  final String uid;
  final String email;
  final UserRole role;
  final String? linkedStudentId; // Only set for parents
  final String? ageGroup; // 4-8, 9-13, 14+

  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.linkedStudentId,
    this.ageGroup,
  });

  bool get isParent => role == UserRole.parent;
  bool get isStudent => role == UserRole.student;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': role.name,
    };
    if (linkedStudentId != null) {
      map['linked_student_id'] = linkedStudentId;
    }
    if (ageGroup != null) {
      map['age_group'] = ageGroup;
    }
    return map;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] == 'parent' ? UserRole.parent : UserRole.student,
      linkedStudentId: map['linked_student_id'],
      ageGroup: map['age_group'],
    );
  }
}

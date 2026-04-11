/// Roles in the app.
enum UserRole { student, parent }

class UserProfile {
  final String uid;
  final String email;
  final UserRole role;
  final String? linkedStudentId; // Only set for parents

  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.linkedStudentId,
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
    return map;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] == 'parent' ? UserRole.parent : UserRole.student,
      linkedStudentId: map['linked_student_id'],
    );
  }
}

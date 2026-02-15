class UserModel {
  final String uid;
  final String email;
  final String role; // 'student', 'teacher', 'hod'
  final String name;
  final String? phone;
  final String? rollNo; // For students
  final String? admissionNumber; // For students
  final String? employeeId; // For teacher/hod
  final String? department;
  final String? class_;
  final String? section;
  final String? designation; // For teacher/hod

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.rollNo,
    this.admissionNumber,
    this.employeeId,
    this.department,
    this.class_,
    this.section,
    this.designation,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      rollNo: map['rollNo'],
      admissionNumber: map['admissionNumber'],
      employeeId: map['employeeId'],
      department: map['department'],
      class_: map['class'],
      section: map['section'],
      designation: map['designation'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'rollNo': rollNo,
      'admissionNumber': admissionNumber,
      'employeeId': employeeId,
      'department': department,
      'class': class_,
      'section': section,
      'designation': designation,
    };
  }
}
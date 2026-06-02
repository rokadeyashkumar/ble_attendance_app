# BLE Attendance App

A Flutter-based attendance management application that uses **Bluetooth Low Energy (BLE)** and **Firebase** to automate attendance tracking for students and teachers.

## Features

* Student Login
* Teacher Login
* HOD Dashboard
* BLE-Based Attendance Marking
* Firebase Authentication
* Attendance Records
* Timetable Management
* Dark & Light Theme Support
* Department-Wise Reports

## Tech Stack

* Flutter
* Dart
* Firebase Authentication
* Cloud Firestore
* Bluetooth Low Energy (BLE)


## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/rokadeyashkumar/ble_attendance_app.git
cd ble_attendance_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

* Create a Firebase project.
* Add your Android app.
* Download `google-services.json`.
* Place it in:

```text
android/app/google-services.json
```

### 4. Run the App

```bash
flutter run
```

## Modules

### Student

* Mark Attendance
* View Attendance Records
* View Timetable
* Manage Profile

### Teacher

* Take Attendance
* Manage Student Records
* View Timetable

### HOD

* View Department Attendance
* Generate Reports
* Monitor Students and Subjects


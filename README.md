# Attendance App

Cross-platform Flutter app for classroom attendance, student contacts, and schedule viewing. Works on Android, iOS, and desktop (Windows enabled).

## Features
- **Attendance flow**: Setup (subject + class start time) → mark Present/Absent (defaults Absent) from read-only student list → export teacher-ready PDF (S.No, Roll, Name, Admission, Status, signature line).
- **Student Contacts**: Searchable list (name, roll, admission, phone). Long-press copies phone number.
- **Schedule viewer**: Opens stored schedule PDF from app-local storage; placeholder if missing.
- **Update Files**: Replace schedule PDF and student list (.xlsx) from device; stored locally and used by Attendance/Contacts/Schedule.
- **Persistent storage**: Uses app documents directory for schedule.pdf and student_list.xlsx. Asset is only a fallback; sensitive files are git-ignored.
<img width="365" height="657" alt="image" src="https://github.com/user-attachments/assets/c199e9b8-45c5-4995-8c59-cb7f55ac34ae" />
<img width="361" height="178" alt="image" src="https://github.com/user-attachments/assets/c0363300-1570-49c7-a013-e1969c0a6cc8" />
<img width="361" height="773" alt="image" src="https://github.com/user-attachments/assets/29a01837-f77e-4c73-9d6c-4269559bcfe2" />
<img width="396" height="782" alt="image" src="https://github.com/user-attachments/assets/c22e6cbe-63ca-4030-8a19-efc6591d52f4" />

## Project Structure (high level)
- `lib/main.dart` — all screens and data handling.
- `assets/app_icon.png` — launcher icon source (processed via `flutter_launcher_icons`).
- `database/` — kept empty; student list is loaded from app storage or an optional asset (not tracked in git).

## Setup & Run
1) Install Flutter SDK and platform deps.
2) Fetch packages:
   ```
   flutter pub get
   ```
3) Run on device/emulator:
   ```
   flutter run -d <device>
   ```
   (e.g., `emulator-5554` for Android, `windows` for desktop)

## Updating Data Files In-App
- From Home → **Update Files** tile:
  - **Update Schedule PDF**: pick a `.pdf`; saved to app storage and used by Schedule screen.
  - **Update Student List (.xlsx)**: pick `.xlsx`; saved to app storage and used by Attendance & Contacts.
- Student list expected columns (header row skipped): `S.No | Roll Number | Name | SBU Admission Number | Phone`.
- If no stored files, Attendance/Contacts will error with a prompt to upload; Schedule shows placeholder.

## Build APK (release)
```
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

## Launcher Icons
Source icon: `assets/app_icon.png`. To regenerate after changing the icon:
```
flutter pub run flutter_launcher_icons
```

## Notes
- Sensitive data files are git-ignored: `/database/*.xlsx`, `/schedule.pdf`.
- No cloud sync; all files are local to the device.

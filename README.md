# MediTwin AI

**MediTwin AI** is a Flutter-based digital health companion designed to help users manage personal wellness data, access AI-assisted health guidance, discover doctors, book appointments, and use emergency healthcare resources from a single, organized platform.

The project focuses on practical healthcare accessibility, clean role-based workflows, privacy-aware doctor contact handling, and a professional cross-platform user experience.

> **Medical disclaimer:** MediTwin AI is not a replacement for licensed medical professionals, emergency services, diagnosis, or treatment. The application is intended for educational, wellness-tracking, and appointment-support purposes only.

---

## Developer

**Sagnik Saha Dibbay**  
**Institution:** Daffodil International University  
**Department:** Information and Communication Engineering  
**GitHub:** [@Sagnik-ICE](https://github.com/Sagnik-ICE)  
**Email:** dibbaysaha17@gmail.com  
**Email:** dibbay242-50-014@diu.edu.bd  

---

## Project Overview

MediTwin AI is built as a role-based healthcare application with separate experiences for:

- **Patients** — track health logs, view analytics, chat with an AI assistant, find doctors, book appointments, manage appointments, and access emergency resources.
- **Doctors** — manage doctor profile information, chamber details, appointment schedule, and availability.
- **Admins** — manage doctors, admins, emergency resources, user records, and platform data through a protected admin workflow.

The application was developed with a strong emphasis on:

- professional UI/UX consistency
- Firebase-backed authentication and data persistence
- Firestore security rules
- doctor/patient data separation
- privacy-conscious public doctor profiles
- scalable role-based architecture

---

## Core Features

### Authentication and User Roles

- Email/password authentication
- Patient registration
- Doctor account support
- Admin account management
- Role-based routing and protected screens
- Account cleanup support for admin-managed user deletion

### Patient Dashboard

- Professional patient home dashboard
- Daily health status overview
- Quick access to health logs, analytics, chat, doctors, appointments, emergency resources, and settings

### Daily Health Log

Patients can record daily wellness data such as:

- basic vitals
- sleep
- hydration
- stress
- symptoms
- wellness indicators

The saved data is used to generate health statistics and trend summaries.

### Health Statistics

- Average health score
- Recent health-log summaries
- Sleep, hydration, and stress indicators
- Trend-oriented health insights
- Risk flag overview
- Professional analytics layout for easier interpretation

### AI Health Assistant

- Chat-based health support interface
- Multiple chat modes, including general wellness, symptoms, nutrition, sleep, and stress
- Conversation reset support
- Designed as a supportive wellness assistant, not a diagnostic tool

### Doctor Directory

- Searchable doctor directory
- Filter doctors by specialty, district, division, and category
- Compact professional doctor cards
- Dedicated doctor profile pages
- Admin doctor creation, editing, and deletion

### Doctor Profile and Chamber Management

Doctor profiles support:

- doctor name
- qualification
- specialty/category
- professional details
- division and district
- chamber list
- chamber address
- chamber appointment contact number
- available days
- patient visiting time slots

For privacy, doctor-level personal contact numbers are not stored or displayed publicly. Appointment contact is stored per chamber instead.

### Appointment Booking

Patients can:

- open doctor profiles
- choose chamber
- choose available date
- choose time block
- request appointments
- view appointment status
- cancel eligible appointments
- see chamber appointment contact details

Appointment records are designed to avoid exposing other patients’ private data.

### My Appointments

- Patient appointment list
- Appointment status display
- Doctor profile access
- Chamber and time block information
- Appointment contact number display when available
- Cancel option for eligible appointments

### Emergency Resources

Admin-managed emergency resource module supporting healthcare-related contact resources such as:

- ambulance
- hospitals
- blood banks
- blood donors
- emergency support records

The emergency module includes search/filter support and a professional section-based layout.

### Admin Management

Admins can manage:

- admin accounts
- user records
- doctor records
- emergency resources
- platform cleanup operations

Admin deletion is designed to clean related Firestore records, including linked user profile/state records where permitted.

### Settings

- Profile access
- Data export support
- Logout
- Delete account workflow
- Clean role-aware settings interface

---

## Technology Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Backend | Firebase |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Platform Target | Web, Android-ready Flutter architecture |
| State Management | Provider-style app state architecture |
| UI System | Material Design with custom professional brand styling |

---

## Project Structure

```text
lib/
├── main.dart
├── providers/
│   └── app_state.dart
├── screens/
│   ├── admin_management_screen.dart
│   ├── analytics_screen.dart
│   ├── auth_screen.dart
│   ├── chat_screen.dart
│   ├── doctor_directory_screen.dart
│   ├── doctor_profile_screen.dart
│   ├── emergency_screen.dart
│   ├── home_dashboard_screen.dart
│   ├── main_shell.dart
│   ├── my_appointments_screen.dart
│   ├── settings_screen.dart
│   ├── splash_screen.dart
│   └── tracking_screen.dart
├── services/
│   ├── firestore_service.dart
│   └── ...
├── theme/
│   └── app_theme.dart
└── widgets/
    └── doctor_photo.dart
```

Additional project files:

```text
firestore.rules
firebase.json
pubspec.yaml
```

---

## Setup Instructions

### Prerequisites

Install the following tools before running the project:

- Flutter SDK
- Dart SDK
- Firebase CLI
- Git
- A Firebase project
- Chrome or Microsoft Edge for Flutter web testing
- Android Studio or VS Code

Check Flutter installation:

```bash
flutter doctor
```

---

## Firebase Setup

1. Create a Firebase project from the Firebase Console.
2. Enable Firebase Authentication.
3. Enable Cloud Firestore.
4. Register the app for the required platforms.
5. Download and place Firebase configuration files in the correct project locations.
6. Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

For Android builds, add the required SHA-1/SHA-256 fingerprints in Firebase project settings and download the updated `google-services.json`.

---

## Running the Project

From the project root:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run -d edge
```

For Chrome:

```bash
flutter run -d chrome
```

---

## Build Commands

### Web Build

```bash
flutter build web
```

### Android Build

```bash
flutter build apk
```

For release builds, make sure Firebase configuration, app signing, and required platform settings are complete.

---

## Firestore Security

The project uses Firestore rules to separate access by role and ownership. Key security principles include:

- users can access only their own private records
- doctors can update their own schedule-related fields
- admins can manage authorized platform records
- public doctor records avoid personal doctor contact exposure
- appointment data is protected from unrelated patients

> Firestore rules should be reviewed before production deployment, especially if new collections or fields are added.

---

## Privacy Considerations

MediTwin AI includes specific privacy-conscious design decisions:

- doctor personal phone numbers are not published in public doctor profiles
- appointment contact numbers are stored per chamber
- patients cannot read other patients’ appointment data
- admin deletion cleans related Firestore profile/state data where permitted
- sensitive actions are role-restricted

---

## Testing Checklist

Before release, test the following flows:

### Patient

- Sign up
- Sign in
- Complete profile
- Add daily health log
- Open health statistics
- Chat with assistant
- Search doctors
- Book appointment
- View appointment
- Cancel appointment
- Open emergency resources
- Export data
- Logout

### Doctor

- Sign in
- Open doctor profile
- Edit schedule
- Add/update chamber details
- Add/update chamber appointment contact
- Verify public profile display

### Admin

- Sign in as admin
- Add doctor
- Edit doctor
- Delete doctor
- Add admin
- Delete admin
- Manage emergency records
- Verify Firestore cleanup after deletion

---

## Current Project Status

The current version includes:

- stable UI redesign
- professional dashboard and screen layouts
- Firebase-backed core workflows
- doctor chamber appointment contact privacy update
- admin Firestore cleanup on delete
- analyzer cleanup for recent Flutter lint/deprecation issues
- successful final run after fixes

---

## Future Improvements

Recommended future enhancements:

- Cloud Functions for secure Firebase Auth user deletion
- Cloud Functions for appointment slot capacity enforcement
- Push notifications for appointment updates
- Doctor-side appointment approval dashboard
- Patient medical document upload
- Prescription management
- In-app video consultation support
- Multi-language support
- Advanced health analytics
- Deployment pipeline with CI/CD
- Automated testing suite

---

## Professional Notes

MediTwin AI demonstrates practical implementation of:

- role-based healthcare workflows
- Firebase Authentication and Firestore integration
- Flutter UI development
- privacy-aware health application design
- admin-controlled platform management
- healthcare appointment and emergency-resource modules

The project is suitable as a strong academic, portfolio, and practical software engineering demonstration in the digital health domain.

---

## License

This project is currently maintained by **Sagnik Saha Dibbay**.  
Add an appropriate open-source license before public production distribution, if required.

---

## Contact

For project discussion, collaboration, or academic review:

**Sagnik Saha Dibbay**  
Daffodil International University  
Department of Information and Communication Engineering  
GitHub: [@Sagnik-ICE](https://github.com/Sagnik-ICE)  
Email: dibbaysaha17@gmail.com  
Email: dibbay242-50-014@diu.edu.bd

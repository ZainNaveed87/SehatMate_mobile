# Source-to-Flutter route parity

All source routes are implemented as responsive Flutter screens. Dynamic IDs use the same sample entities as the supplied prototype.

| Source route | Flutter screen |
| --- | --- |
| `/` | `LandingScreen` |
| `/auth` | `AuthScreen` |
| `/onboarding` | `OnboardingScreen` |
| `/dashboard` | `DashboardScreen` |
| `/care-plans` | `CarePlansScreen` |
| `/care-plan/new` | `NewCarePlanScreen` |
| `/care-plan/upload` | `CarePlanUploadScreen` |
| `/care-plan/review` | `CarePlanReviewScreen` |
| `/reality-check` | `RealityCheckScreen` |
| `/simulation` | `SimulationScreen` |
| `/care-plan/:id` | `CarePlanDetailScreen` |
| `/calendar` | `CalendarScreen` |
| `/care-gaps` | `CareGapsScreen` |
| `/care-gaps/:id` | `CareGapDetailScreen` |
| `/doctor-questions` | `DoctorQuestionsScreen` |
| `/documents` | `DocumentsScreen` |
| `/family` | `FamilyScreen` |
| `/family/new` | `AddCaregiverScreen` |
| `/family/:id` | `CaregiverDetailScreen` |
| `/notifications` | `NotificationsScreen` |
| `/patient-profile` | `PatientProfileScreen` |
| `/progress` | `ProgressScreen` |
| `/settings` | `SettingsScreen` |
| `/simple-care` | `SimpleCareScreen` |
| `/teach-back` | `TeachBackScreen` |

## Preserved UI behavior

- Desktop sidebar, sticky headers, mobile bottom navigation and overflow menus
- Responsive one-, two-, three- and four-column layouts at matching breakpoints
- Shared task, care-gap, caregiver, notification, document and preference state
- Tabs, filters, dialogs, bottom sheets, forms, progress indicators and collapsible FAQs
- 220 ms page and list fade/slide motion, card hover lift and processing progress
- Reduced-motion, large-text, Simple Care, language and voice-guidance preferences

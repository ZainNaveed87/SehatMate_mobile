# SehatMate hackathon review update

This build keeps the existing visual system and changes only the care-plan review flow.

## Included

- Compact review cards and an at-a-glance review summary
- Empty categories remain hidden
- Long ambiguity and trusted-source content opens in a scrollable bottom sheet
- Trusted-source results no longer expand the main list
- Optional JPG/PNG ingredient-label evidence upload for medicine cards
- Ingredient, strength, form and manufacturer transcription
- Source-grounded ingredient-purpose consistency result
- Doctor-question and edit flows remain available from item details

Ingredient evidence never overwrites a prescription and never confirms a patient-specific dose.

## Run

```powershell
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=https://sehatmate-api.secretstechies.com/api --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```


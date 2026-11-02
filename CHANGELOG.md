# Changelog

## 1.2.0

- Compile and target Android 16 / API 36 while retaining Android 8+ support.
- Generate a signed Android App Bundle as well as a compatible signed APK.
- Update Android build tooling and test reminder behavior on Android 16.
- Apply system-bar, cutout and keyboard insets once in the offline shell.
- Add an offline English/Spanish privacy policy in Settings and a matching public policy page.
- Prepare store listing copy and a checklist for a future Google Play submission.

## 1.1.1

- Open reflection reminders directly from a labeled bell in the app header.
- Show saved reminder and blocked-notification status on the shortcut.
- Place the reminder entry near the top of Settings with its own bell icon.
- Preserve existing scores, notes, history, and reminder schedules when updating.

## 1.1.0

- Start new installations without preset scores, notes, or evaluations.
- Distinguish unanswered areas from an intentional zero.
- Add optional daily, weekly, and monthly reflection reminders with a local time.
- Support switching reminders off, Android notification permissions, and rescheduling after reboot or calendar changes.
- Add a confirmed action to clear local reflection data and disable reminders.
- Preserve existing reflections when upgrading and importing older backups.
- Verify calendar recurrence, Android scheduling, cancellation, and reminder controls with automated tests.

## 1.0.1

- Remove the fixed Draft/Borrador badge from the main wheel.

## 1.0.0

- Introduce the offline wheel of life, editable scores, per-category notes, historical comparisons, and JSON backup/import.

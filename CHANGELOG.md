# Changelog

## 1.3.0 (Android) / 1.2.0 build 8 (iPhone)

- Keep three optional reflection prompts visible beside each area note on Android, iPhone and the browser app.
- Invite reflection on recent actions, other possibilities or obstacles, and a next small step.
- Preserve free-text notes, automatic saving, history and existing backup compatibility.

## 1.2.1 (Android) / 1.1.1 build 7 (iPhone)

- Keep portable backups within a consistent compact UTF-8 byte limit and preserve original recovery data.
- Prevent concurrent upgraded browser pages from silently replacing newer reflections.
- Show persistent failed-save recovery and retain unsaved draft export access.
- Preserve Android picker work across recreation and perform provider I/O in the background.
- Recover native iPhone files without reinstalling and restore actual reminder requests after failed changes.
- Keep reset completion tied to native reminder-disable and state-write success.
- Improve reading contrast and scalable iPhone typography; declare the actual preference API usage.
- Bind release verification claims to current source/check outputs and artifact hashes.
- Clarify browser offline readiness, website entry translations and dated distribution observations.

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

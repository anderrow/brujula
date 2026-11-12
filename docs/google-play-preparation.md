# Google Play preparation — Brújula 1.2.1

Prepared on November 2, 2026. **No app has been uploaded to Play Console, submitted for review, or published on Google Play.** This checklist is preparation, not a guarantee of store acceptance. Recheck requirements when you decide to submit.

## Build and signing

- Application ID: `app.brujula.life`; version name `1.2.1`; version code `6`.
- Minimum Android API: 26 (Android 8). Compile and target API: 36 (Android 16).
- Release bundle: `Brujula-1.2.1.aab`. This is the file for a future Play Console release; it cannot be installed directly on a phone.
- Direct installation/update: `Brujula-1.2.1.apk`.
- Both files use the existing Brújula release signing certificate. Check their adjacent SHA-256 files.
- Expected certificate SHA-256: `9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe`.
- Retain the private release keystore and its protected password outside the public repository. Neither is included in delivery archives.
- When configuring Play App Signing, arrange to retain the existing app signing key if Play-installed and website-installed APKs must update one another. Do not accept an unrelated generated signing identity by accident. Use Google's secure key import process when required; an upload key is a separate role. Review any newer Play signing/rotation requirements at enrollment.
- Runtime code has no bundled native `.so` libraries, so no native ELF alignment migration is required for 16 KB pages. Still test on an Android 16 / 16 KB device or emulator before release.

## Store listing copy

Title (both locales): **Brújula**.

English short description (80-character limit):

> Reflect on your life with a private wheel, notes, history and reminders.

Spanish short description:

> Tu rueda de la vida privada, con notas, historial y recordatorios opcionales.

English full description:

> Make a little space for yourself with Brújula. Reflect on eight areas of your life: health, work, finances, family, friends, partner, leisure and growth.
>
> Start with a clean wheel and rate each area from 0 to 10. Write a personal note, save a check-in and compare your reflections over time. Your history keeps the scores and notes from each saved moment.
>
> Choose an optional daily, weekly or monthly reminder at a local time, or turn reminders off whenever you like. Android battery management may delay notifications.
>
> Your reflections stay on your device. No sign-in, ads, analytics or Internet connection are required. Export and restore local JSON backups when you choose. Export before uninstalling or changing phones; exported files include your notes and are not encrypted by Brújula.
>
> Available in English and Spanish. Brújula is a personal reflection tool, not a medical device. It does not diagnose, treat, cure or prevent medical conditions and does not replace professional advice.

Spanish full description:

> Encuentra un pequeño espacio para ti con Brújula. Reflexiona sobre ocho áreas de tu vida: salud, trabajo, finanzas, familia, amistades, pareja, ocio y crecimiento.
>
> Empieza con una rueda vacía y valora cada área de 0 a 10. Escribe una nota, guarda una evaluación y compara tus reflexiones con el tiempo. El historial conserva las puntuaciones y notas de cada momento guardado.
>
> Elige un recordatorio diario, semanal o mensual a una hora local, o desactívalo cuando quieras. El ahorro de batería de Android puede retrasar las notificaciones.
>
> Tus reflexiones se quedan en tu dispositivo. Sin inicio de sesión, anuncios, analítica ni conexión a Internet. Exporta y restaura copias locales JSON cuando tú decidas. Exporta antes de desinstalar o cambiar de teléfono: las copias incluyen tus notas y Brújula no las cifra.
>
> Disponible en español e inglés. Brújula es una herramienta de reflexión personal, no un producto sanitario. No diagnostica, trata, cura ni previene enfermedades y no sustituye el consejo profesional.

Suggested category: Lifestyle. Confirm the appropriate category and intended audience in Play Console rather than inferring an age rating.

## Privacy and declarations

- Public privacy URL: `https://anderrow.github.io/brujula/privacy.html`. The same policy is available offline under Settings → Privacy policy, in both languages.
- App access: all features are accessible without credentials; no reviewer account is required.
- Ads: none. No ads SDK or advertising ID permission.
- Data Safety draft: the app does not collect or share data off-device. Scores, notes and history are processed locally. An export goes to the document destination selected by the user; the app does not receive data from that destination. Review the current form and Google's definition of collection before submitting. Do not claim an independent security audit, encryption of exported backups, or features that do not exist.
- No account creation or server account exists. Local data can be deleted in Settings, through Android storage controls, or by uninstalling. Exported copies require separate deletion by the user.
- Permissions: notifications for optional reminders; reboot receiver to restore an enabled schedule. No Internet, location, health sensor, Health Connect, broad storage, or exact-alarm permission.
- Complete the Health apps declaration, including for testing tracks. Assess the current form's mental-wellbeing/general-wellness categories honestly for a life-reflection app. The presence of a Health area is not a medical certification. No diagnosis, treatment, clinical accuracy or medical outcome is claimed.
- Complete content rating, target audience, countries, pricing, and any declarations shown by the console. No rating has been assigned yet.

## Work that remains outside the build

1. Create and verify the developer account, pay the registration fee, and complete device verification if required.
2. Confirm the developer identity and public support email that you want shown. The privacy policy currently offers GitHub Issues as a contact mechanism. **Issues are public; never post reflections, backups or sensitive personal information.** Play's listing requires a support email; none has been invented or published for you.
3. Review the listing copy, privacy policy and declarations against the final app and current Google policies.
4. Inspect the draft 512×512 icon and 1024×500 feature graphics in the delivery archive. Browser-rendered app previews are labeled as drafts; replace or verify them with real Android screenshots before submission. Never use personal reflections in screenshots.
5. Test the signed release on actual Android versions, including Android 16, notification permission denial, reboot/rescheduling, system back, IME/cutouts, file import/export, accessibility and an in-place update with a backup available.
6. Upload the AAB to a testing track only when you choose to. New personal accounts created after November 13, 2023 normally need at least 12 continuously opted-in closed testers for 14 days, followed by an application for production access. Meet the actual requirements shown for your account.
7. Review pre-launch reports, resolve any findings, obtain production access where required, then submit a production release for review.

## Official references

- [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Create and set up an app](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Privacy policy and user data](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Health declaration](https://support.google.com/googleplay/android-developer/answer/14738291)
- [Preview assets](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Personal-account testing](https://support.google.com/googleplay/android-developer/answer/14151465)

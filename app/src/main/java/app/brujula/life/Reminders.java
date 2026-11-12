package app.brujula.life;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import org.json.JSONObject;
import java.time.ZonedDateTime;

/** One local alarm at a time. Settings and alarm cancellation are independent of app data. */
public final class Reminders {
    static final String CHANNEL = "reflection";
    static final String ACTION = "app.brujula.life.REFLECTION";
    private static final int NOTIFICATION_ID = 41;
    private static volatile boolean registrationFailed;
    private Reminders() { }
    private static SharedPreferences prefs(Context ctx) { return ctx.getSharedPreferences("reminders", Context.MODE_PRIVATE); }
    public static void ensureChannel(Context ctx) {
        NotificationManager manager = ctx.getSystemService(NotificationManager.class);
        manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Reflection reminders", NotificationManager.IMPORTANCE_DEFAULT));
    }
    public static boolean allowed(Context ctx) {
        NotificationManager manager = ctx.getSystemService(NotificationManager.class);
        NotificationChannel channel = manager.getNotificationChannel(CHANNEL);
        return (Build.VERSION.SDK_INT < 33 || ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
            && manager.areNotificationsEnabled() && (channel == null || channel.getImportance() != NotificationManager.IMPORTANCE_NONE);
    }
    public static JSONObject settings(Context ctx) {
        try {
            JSONObject value = new JSONObject(prefs(ctx).getString("config", "{}"));
            value.put("enabled", value.optBoolean("enabled", false));
            value.put("frequency", value.optString("frequency", "daily"));
            value.put("hour", value.optInt("hour", 20));
            value.put("minute", value.optInt("minute", 0));
            value.put("weekday", value.optInt("weekday", 1));
            value.put("monthDay", value.optInt("monthDay", 1));
            value.put("locale", value.optString("locale", "es"));
            value.put("canNotify", allowed(ctx));
            long registeredAt = prefs(ctx).getLong("registeredAt", 0);
            boolean registered = value.getBoolean("enabled") && allowed(ctx) && registeredAt > 0 && !registrationFailed;
            value.put("registered", registered);
            value.put("nextAt", registered ? registeredAt : 0);
            return value;
        } catch (Exception e) { throw new IllegalStateException("Cannot read reminder settings", e); }
    }
    static ZonedDateTime next(JSONObject value) throws Exception {
        return ReminderSchedule.next(ZonedDateTime.now(), value.getString("frequency"), value.getInt("hour"), value.getInt("minute"), value.getInt("weekday"), value.getInt("monthDay"));
    }
    public static JSONObject parse(String json) throws Exception {
        JSONObject raw = new JSONObject(json), value = new JSONObject();
        value.put("enabled", raw.getBoolean("enabled"));
        value.put("frequency", raw.getString("frequency"));
        for (String key : new String[]{"hour", "minute", "weekday", "monthDay"}) {
            Object number = raw.get(key);
            if (!(number instanceof Number) || ((Number)number).doubleValue() != ((Number)number).intValue()) throw new IllegalArgumentException("Invalid reminder number");
            value.put(key, ((Number)number).intValue());
        }
        value.put("locale", "en".equals(raw.optString("locale")) ? "en" : "es");
        next(value); // Validates every recurrence field, including disabled configurations.
        return value;
    }
    // Commit synchronously so the persisted enabled flag and registered alarm agree,
    // including rollback if AlarmManager rejects the new schedule.
    @SuppressLint("ApplySharedPref")
    public static synchronized boolean save(Context ctx, JSONObject value) {
        String previous = prefs(ctx).getString("config", "{}");
        if (!prefs(ctx).edit().putString("config", value.toString()).commit()) {
            // A failed disk commit has already changed the in-memory preferences map.
            prefs(ctx).edit().putString("config", previous).commit();
            return false;
        }
        try { reschedule(ctx); return true; }
        catch (Exception e) {
            prefs(ctx).edit().putString("config", previous).commit();
            try { reschedule(ctx); } catch (Exception ignored) { }
            return false;
        }
    }
    @SuppressLint("ApplySharedPref")
    static synchronized void restoreAfterFailedReset(Context ctx, JSONObject previous) {
        registrationFailed = true;
        if (!prefs(ctx).edit().putString("config", previous.toString()).putLong("registeredAt", 0).commit()) {
            throw new IllegalStateException("Cannot restore reminder preferences");
        }
        // Keep restored intent even if AlarmManager fails; a later foreground retry can register it.
        reschedule(ctx);
    }
    private static PendingIntent alarm(Context ctx) {
        return PendingIntent.getBroadcast(ctx, 0, new Intent(ctx, ReminderReceiver.class).setAction(ACTION), PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
    public static synchronized void reschedule(Context ctx) {
        registrationFailed = true;
        prefs(ctx).edit().putLong("registeredAt", 0).commit();
        ensureChannel(ctx);
        AlarmManager manager = ctx.getSystemService(AlarmManager.class);
        manager.cancel(alarm(ctx));
        JSONObject value = settings(ctx);
        if (!value.optBoolean("enabled")) {
            ctx.getSystemService(NotificationManager.class).cancel(NOTIFICATION_ID);
            registrationFailed = false;
            return;
        }
        if (!allowed(ctx)) return;
        try {
            long at = next(value).toInstant().toEpochMilli();
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarm(ctx));
            if (!prefs(ctx).edit().putLong("registeredAt", at).commit()) throw new IllegalStateException("Cannot preserve registration status");
            registrationFailed = false;
        } catch (Exception e) { throw new IllegalStateException("Cannot schedule reminder", e); }
    }
    public static synchronized void deliver(Context ctx) {
        JSONObject value = settings(ctx);
        if (!value.optBoolean("enabled")) return;
        ensureChannel(ctx);
        if (allowed(ctx)) {
            boolean es = !"en".equals(value.optString("locale"));
            Intent open = new Intent(ctx, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            PendingIntent content = PendingIntent.getActivity(ctx, 0, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            Notification notice = new Notification.Builder(ctx, CHANNEL)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(es ? "Un momento para ti" : "A moment for yourself")
                .setContentText(es ? "¿Cómo estás hoy? Abre Brújula y dedica un momento a tu reflexión." : "How are you today? Open Brújula and take a moment to reflect.")
                .setContentIntent(content).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE)
                .setCategory(Notification.CATEGORY_REMINDER).build();
            // allowed() checks POST_NOTIFICATIONS on Android 13+, and channel/app settings.
            try { ctx.getSystemService(NotificationManager.class).notify(NOTIFICATION_ID, notice); }
            catch (SecurityException ignored) { }
        }
        reschedule(ctx);
    }
}

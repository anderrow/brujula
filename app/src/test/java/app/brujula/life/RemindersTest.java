package app.brujula.life;

import android.Manifest;
import android.app.AlarmManager;
import android.app.Application;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.Implements;
import org.robolectric.annotation.Implementation;
import org.robolectric.shadows.ShadowAlarmManager;
import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {33, 36}, shadows = RemindersTest.FailingAlarmManager.class)
public class RemindersTest {
    @Implements(AlarmManager.class)
    public static class FailingAlarmManager extends ShadowAlarmManager {
        static int rejectAdds, rejectCancels;
        @Implementation @Override protected void setAndAllowWhileIdle(int type, long at, PendingIntent intent) {
            if (rejectAdds > 0) { rejectAdds--; throw new SecurityException("Synthetic scheduling failure"); }
            super.setAndAllowWhileIdle(type, at, intent);
        }
        @Implementation @Override protected void cancel(PendingIntent intent) {
            if (rejectCancels > 0) { rejectCancels--; throw new SecurityException("Synthetic cancellation failure"); }
            super.cancel(intent);
        }
    }
    private Application app;
    private AlarmManager alarms;
    private NotificationManager notifications;
    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        FailingAlarmManager.rejectAdds = 0; FailingAlarmManager.rejectCancels = 0;
        app.getSharedPreferences("reminders", 0).edit().clear().commit();
        alarms = app.getSystemService(AlarmManager.class);
        notifications = app.getSystemService(NotificationManager.class);
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS);
        Reminders.ensureChannel(app);
    }
    private JSONObject config(boolean enabled, String frequency) throws Exception {
        return Reminders.parse("{\"enabled\":"+enabled+",\"frequency\":\""+frequency+"\",\"hour\":20,\"minute\":30,\"weekday\":5,\"monthDay\":31,\"locale\":\"en\"}");
    }
    @Test public void freshInstallIsDisabledAndHasNoAlarm() {
        Reminders.reschedule(app);
        assertFalse(Reminders.settings(app).optBoolean("enabled"));
        assertEquals(0, shadowOf(alarms).getScheduledAlarms().size());
        assertEquals(0, shadowOf(notifications).getAllNotifications().size());
    }
    @Test public void replacingScheduleLeavesOnlyOneFutureAlarm() throws Exception {
        for (String frequency : new String[]{"daily", "weekly", "monthly"}) {
            assertTrue(Reminders.save(app, config(true, frequency)));
            assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
            assertEquals(frequency, Reminders.settings(app).getString("frequency"));
            assertTrue(Reminders.settings(app).getLong("nextAt") > System.currentTimeMillis());
        }
    }
    @Test public void deliveryPostsPrivateNotificationAndSchedulesNext() throws Exception {
        Reminders.save(app, config(true, "daily"));
        new ReminderReceiver().onReceive(app, new Intent(Reminders.ACTION));
        assertEquals(1, shadowOf(notifications).getAllNotifications().size());
        Notification notice = shadowOf(notifications).getAllNotifications().get(0);
        assertEquals("A moment for yourself", notice.extras.getString(Notification.EXTRA_TITLE));
        assertEquals(Notification.VISIBILITY_PRIVATE, notice.visibility);
        assertNotNull(notice.contentIntent);
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
    }
    @Test public void disablingCancelsAlarmsAndVisibleNoticeAndCannotNotifyAgain() throws Exception {
        Reminders.save(app, config(true, "weekly"));
        Reminders.deliver(app);
        assertTrue(Reminders.save(app, config(false, "weekly")));
        assertEquals(0, shadowOf(alarms).getScheduledAlarms().size());
        assertEquals(0, shadowOf(notifications).getAllNotifications().size());
        Reminders.deliver(app);
        assertEquals(0, shadowOf(notifications).getAllNotifications().size());
    }
    @Test public void bootAndTimezoneChangesRestoreOnlyEnabledSchedules() throws Exception {
        Reminders.save(app, config(true, "monthly"));
        for (String action : new String[]{Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED}) {
            new ReminderReceiver().onReceive(app, new Intent(action));
            assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        }
        Reminders.save(app, config(false, "monthly"));
        new ReminderReceiver().onReceive(app, new Intent(Intent.ACTION_BOOT_COMPLETED));
        assertEquals(0, shadowOf(alarms).getScheduledAlarms().size());
    }
    @Test public void deniedPermissionPreventsSchedulingAndDelivery() throws Exception {
        shadowOf(app).denyPermissions(Manifest.permission.POST_NOTIFICATIONS);
        assertFalse(Reminders.allowed(app));
        Reminders.save(app, config(true, "daily"));
        Reminders.deliver(app);
        assertEquals(0, shadowOf(alarms).getScheduledAlarms().size());
        assertEquals(0, shadowOf(notifications).getAllNotifications().size());
    }
    @Test public void invalidCalendarConfigIsRejected() throws Exception {
        JSONObject raw=config(true,"daily");raw.put("monthDay",32);
        try { Reminders.parse(raw.toString()); fail("Invalid month day accepted"); }
        catch (IllegalArgumentException expected) { }
    }
    @Test public void rejectedRegistrationRestoresPreviousScheduleAndReportsFailedRollback() throws Exception {
        assertTrue(Reminders.save(app, config(true, "daily")));
        FailingAlarmManager.rejectAdds = 1;
        assertFalse(Reminders.save(app, config(true, "weekly")));
        assertEquals("daily", Reminders.settings(app).getString("frequency"));
        assertTrue(Reminders.settings(app).getBoolean("registered"));
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        FailingAlarmManager.rejectAdds = 2;
        assertFalse(Reminders.save(app, config(true, "weekly")));
        assertFalse(Reminders.settings(app).getBoolean("registered"));
        assertEquals(0, Reminders.settings(app).getLong("nextAt"));
        Reminders.reschedule(app);
        assertTrue(Reminders.settings(app).getBoolean("registered"));
    }
    @Test public void rejectedCancellationStopsResetBeforeReflectionReplacement() throws Exception {
        assertTrue(Reminders.save(app, config(true, "daily")));
        try (android.database.sqlite.SQLiteDatabase db = android.database.sqlite.SQLiteDatabase.create(null)) {
            db.execSQL("CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL)");
            assertTrue(MainActivity.writeState(db, "{\"original\":true}", null));
            FailingAlarmManager.rejectCancels = 1;
            assertFalse(MainActivity.resetState(app, db, "{}"));
            assertEquals("{\"original\":true}", MainActivity.readState(db));
            assertTrue(Reminders.settings(app).getBoolean("enabled"));
            assertTrue(Reminders.settings(app).getBoolean("registered"));
        }
    }
}

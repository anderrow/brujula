package app.brujula.life;

import android.Manifest;
import android.app.AlarmManager;
import android.app.Application;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Intent;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33)
public class RemindersTest {
    private Application app;
    private AlarmManager alarms;
    private NotificationManager notifications;
    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
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
}

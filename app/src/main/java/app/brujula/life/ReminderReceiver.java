package app.brujula.life;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Explicit local alarm receiver, also re-registers alarms after system calendar changes. */
public final class ReminderReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        try {
            if (Reminders.ACTION.equals(intent.getAction())) Reminders.deliver(context);
            else Reminders.reschedule(context);
        } catch (RuntimeException ignored) {
            // Preferences remain intact; the next foreground launch retries registration.
        }
    }
}

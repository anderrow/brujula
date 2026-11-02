import app.brujula.life.ReminderSchedule;
import java.time.ZonedDateTime;

/** Run using the workspace JDK; exercises the production calendar calculator. */
public final class ReminderScheduleTest {
    private static int passed;
    private static void next(String now, String frequency, int hour, int minute, int weekday, int day, String expected) {
        ZonedDateTime actual = ReminderSchedule.next(ZonedDateTime.parse(now), frequency, hour, minute, weekday, day);
        if (!actual.equals(ZonedDateTime.parse(expected))) throw new AssertionError(actual + " != " + expected);
        passed++;
    }
    public static void main(String[] args) {
        next("2026-11-02T12:00+01:00[Europe/Amsterdam]", "daily",20,15,1,1,"2026-11-02T20:15+01:00[Europe/Amsterdam]");
        next("2026-11-02T20:15+01:00[Europe/Amsterdam]", "daily",20,15,1,1,"2026-11-03T20:15+01:00[Europe/Amsterdam]");
        next("2026-11-02T21:00+01:00[Europe/Amsterdam]", "weekly",20,0,1,1,"2026-11-09T20:00+01:00[Europe/Amsterdam]");
        next("2026-11-02T12:00+01:00[Europe/Amsterdam]", "weekly",20,0,5,1,"2026-11-06T20:00+01:00[Europe/Amsterdam]");
        next("2026-11-01T12:00+01:00[Europe/Amsterdam]", "weekly",20,0,7,1,"2026-11-01T20:00+01:00[Europe/Amsterdam]");
        next("2026-01-31T21:00+01:00[Europe/Amsterdam]", "monthly",20,0,1,31,"2026-02-28T20:00+01:00[Europe/Amsterdam]");
        next("2028-01-31T21:00+01:00[Europe/Amsterdam]", "monthly",20,0,1,31,"2028-02-29T20:00+01:00[Europe/Amsterdam]");
        next("2026-02-28T21:00+01:00[Europe/Amsterdam]", "monthly",20,0,1,31,"2026-03-31T20:00+02:00[Europe/Amsterdam]");
        next("2026-12-31T21:00+01:00[Europe/Amsterdam]", "monthly",20,0,1,31,"2027-01-31T20:00+01:00[Europe/Amsterdam]");
        next("2027-03-27T21:00+01:00[Europe/Amsterdam]", "daily",2,30,1,1,"2027-03-28T03:30+02:00[Europe/Amsterdam]");
        next("2026-10-24T21:00+02:00[Europe/Amsterdam]", "daily",2,30,1,1,"2026-10-25T02:30+02:00[Europe/Amsterdam]");
        next("2026-10-25T02:45+02:00[Europe/Amsterdam]", "daily",2,30,1,1,"2026-10-26T02:30+01:00[Europe/Amsterdam]");
        next("2026-11-02T23:59Z[UTC]", "daily",0,0,1,1,"2026-11-03T00:00Z[UTC]");
        try { ReminderSchedule.next(ZonedDateTime.now(),"daily",24,0,1,1); throw new AssertionError("Invalid hour accepted"); }
        catch (IllegalArgumentException expected) { passed++; }
        try { ReminderSchedule.next(ZonedDateTime.now(),"invalid",20,0,1,1); throw new AssertionError("Invalid frequency accepted"); }
        catch (IllegalArgumentException expected) { passed++; }
        System.out.println(passed + " reminder calendar checks passed");
    }
}

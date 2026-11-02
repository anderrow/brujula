package app.brujula.life;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.time.DayOfWeek;

/** Calendar-based wall-clock recurrence, independent of Android for deterministic testing. */
public final class ReminderSchedule {
    private ReminderSchedule() { }
    public static ZonedDateTime next(ZonedDateTime now, String frequency, int hour, int minute, int weekday, int monthDay) {
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || weekday < 1 || weekday > 7 || monthDay < 1 || monthDay > 31)
            throw new IllegalArgumentException("Invalid reminder date or time");
        LocalTime time = LocalTime.of(hour, minute);
        LocalDate date = now.toLocalDate();
        ZonedDateTime result;
        switch (frequency) {
            case "daily":
                result = date.atTime(time).atZone(now.getZone());
                if (!result.isAfter(now)) result = date.plusDays(1).atTime(time).atZone(now.getZone());
                return result;
            case "weekly":
                date = date.with(TemporalAdjusters.nextOrSame(DayOfWeek.of(weekday)));
                result = date.atTime(time).atZone(now.getZone());
                if (!result.isAfter(now)) result = date.plusWeeks(1).atTime(time).atZone(now.getZone());
                return result;
            case "monthly":
                YearMonth month = YearMonth.from(date);
                result = month.atDay(Math.min(monthDay, month.lengthOfMonth())).atTime(time).atZone(now.getZone());
                if (!result.isAfter(now)) {
                    month = month.plusMonths(1);
                    result = month.atDay(Math.min(monthDay, month.lengthOfMonth())).atTime(time).atZone(now.getZone());
                }
                return result;
            default: throw new IllegalArgumentException("Invalid reminder frequency");
        }
    }
}

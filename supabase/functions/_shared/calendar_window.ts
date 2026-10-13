// Keep two extra civil dates in the collected publication. A valid snapshot
// can cross two midnights during the strict 36-hour freshness window. The
// product window remains fourteen days; these dates are a rollover reserve.
export const calendarRolloverBufferDays = 2;

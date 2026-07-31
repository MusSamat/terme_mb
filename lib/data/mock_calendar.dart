import 'mock_trips.dart';

/// Per-day ride counts for the calendar / date-stepper — now derived from the
/// actual sample trips so the counts and date filter agree. Replaced by the
/// /trips/calendar endpoint in ТЗ step 2.
Map<String, int> mockCalendarCounts() => tripCalendarCounts();

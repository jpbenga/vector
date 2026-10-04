/// Display order never changes the semantic home/away sides in stored data.
enum SportParticipantOrder { homeAway, awayHome }

/// Scheduling knobs are shared; endpoint selection and caching stay in adapters.
class SportDataPolicy {
  const SportDataPolicy({
    this.calendarDays = 14,
    this.analysisDays = 4,
    this.resultsDaysBack = 7,
    this.maximumSnapshotAge = const Duration(hours: 36),
  });

  final int calendarDays;
  final int analysisDays;
  final int resultsDaysBack;
  final Duration maximumSnapshotAge;

  void validate() {
    if (calendarDays < 1 ||
        analysisDays < 1 ||
        analysisDays > calendarDays ||
        resultsDaysBack < 1 ||
        maximumSnapshotAge <= Duration.zero) {
      throw ArgumentError('Invalid sport data windows.');
    }
  }
}

/// Quota keys represent a provider subscription, never an individual user.
/// Server collectors must enforce these limits atomically; this configuration
/// is not itself a quota counter and contains no API credentials.
class SportProviderPolicy {
  const SportProviderPolicy({
    required this.provider,
    required this.quotaKey,
    required this.dailyLimit,
    required this.minuteLimit,
  });

  final String provider;
  final String quotaKey;
  final int dailyLimit;
  final int minuteLimit;

  void validate() {
    if (provider.trim().isEmpty ||
        quotaKey.trim().isEmpty ||
        dailyLimit < 1 ||
        minuteLimit < 1) {
      throw ArgumentError('Invalid provider quota policy.');
    }
  }
}

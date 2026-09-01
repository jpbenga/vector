import 'generated_ticket.dart';
import 'generated_ticket_pick.dart';
import 'ticket_draft.dart';

enum SavedTicketSource { copilot, copilotModified, manual }

enum SavedTicketStatus { saved, played, won, lost, cancelled }

class SavedTicketPlayDeclaration {
  const SavedTicketPlayDeclaration({
    required this.bookmaker,
    required this.stake,
    required this.actualTotalOdds,
    required this.playedAt,
  });

  final String bookmaker;
  final double? stake;
  final double? actualTotalOdds;
  final DateTime playedAt;

  Map<String, Object?> toJson() {
    return {
      'bookmaker': bookmaker,
      'stake': stake,
      'actualTotalOdds': actualTotalOdds,
      'playedAt': playedAt.toUtc().toIso8601String(),
    };
  }

  static SavedTicketPlayDeclaration fromJson(Map<String, Object?> json) {
    return SavedTicketPlayDeclaration(
      bookmaker: _stringValue(json['bookmaker']) ?? '',
      stake: _doubleValue(json['stake']),
      actualTotalOdds: _doubleValue(json['actualTotalOdds']),
      playedAt: _dateValue(json['playedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

class SavedTicketSelection {
  const SavedTicketSelection({
    required this.id,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.competitionName,
    required this.marketId,
    required this.marketLabel,
    required this.selectionId,
    required this.selectionLabel,
    required this.odds,
    this.homeLogoUrl,
    this.awayLogoUrl,
    this.bookmakerName,
    this.opportunityId,
  });

  final String id;
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String competitionName;
  final String marketId;
  final String marketLabel;
  final String selectionId;
  final String selectionLabel;
  final double odds;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final String? bookmakerName;
  final String? opportunityId;

  String get matchLabel => '$homeTeam - $awayTeam';

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'matchId': matchId,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'competitionName': competitionName,
      'marketId': marketId,
      'marketLabel': marketLabel,
      'selectionId': selectionId,
      'selectionLabel': selectionLabel,
      'odds': odds,
      'homeLogoUrl': homeLogoUrl,
      'awayLogoUrl': awayLogoUrl,
      'bookmakerName': bookmakerName,
      'opportunityId': opportunityId,
    };
  }

  static SavedTicketSelection fromJson(Map<String, Object?> json) {
    return SavedTicketSelection(
      id: _stringValue(json['id']) ?? '',
      matchId: _stringValue(json['matchId']) ?? '',
      homeTeam: _stringValue(json['homeTeam']) ?? '',
      awayTeam: _stringValue(json['awayTeam']) ?? '',
      competitionName: _stringValue(json['competitionName']) ?? '',
      marketId: _stringValue(json['marketId']) ?? '',
      marketLabel: _stringValue(json['marketLabel']) ?? '',
      selectionId: _stringValue(json['selectionId']) ?? '',
      selectionLabel: _stringValue(json['selectionLabel']) ?? '',
      odds: _normalizeOdds(_doubleValue(json['odds']) ?? 0),
      homeLogoUrl: _stringValue(json['homeLogoUrl']),
      awayLogoUrl: _stringValue(json['awayLogoUrl']),
      bookmakerName: _stringValue(json['bookmakerName']),
      opportunityId: _stringValue(json['opportunityId']),
    );
  }

  static SavedTicketSelection fromDraftSelection(
    TicketDraftSelection selection,
  ) {
    return SavedTicketSelection(
      id: selection.id,
      matchId: selection.matchId,
      homeTeam: selection.homeTeam,
      awayTeam: selection.awayTeam,
      homeLogoUrl: selection.homeLogoUrl,
      awayLogoUrl: selection.awayLogoUrl,
      competitionName: selection.competitionName ?? 'Competition',
      marketId: selection.marketId,
      marketLabel: selection.marketLabel,
      selectionId: selection.selectionId,
      selectionLabel: selection.selectionLabel,
      odds: selection.odds,
      bookmakerName: selection.bookmakerName,
    );
  }
}

class SavedTicket {
  const SavedTicket({
    required this.schemaVersion,
    required this.id,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.totalOdds,
    required this.selections,
    this.name,
    this.strategyId,
    this.strategyName,
    this.plannedStake,
    this.playedDeclaration,
    this.mainCombinedReadingId,
    this.mainCombinedReadingLabel,
    this.opportunityIds = const [],
    this.modificationSummary,
    this.modificationDetails = const [],
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final SavedTicketSource source;
  final SavedTicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalOdds;
  final List<SavedTicketSelection> selections;
  final String? name;
  final String? strategyId;
  final String? strategyName;
  final double? plannedStake;
  final SavedTicketPlayDeclaration? playedDeclaration;
  final String? mainCombinedReadingId;
  final String? mainCombinedReadingLabel;
  final List<String> opportunityIds;
  final String? modificationSummary;
  final List<String> modificationDetails;

  int get selectionCount => selections.length;

  bool get isManual => source == SavedTicketSource.manual;

  bool get isEdited => source == SavedTicketSource.copilotModified;

  SavedTicket copyWith({
    String? name,
    SavedTicketSource? source,
    SavedTicketStatus? status,
    DateTime? updatedAt,
    double? plannedStake,
    SavedTicketPlayDeclaration? playedDeclaration,
    double? totalOdds,
    List<SavedTicketSelection>? selections,
    List<String>? opportunityIds,
    String? modificationSummary,
    List<String>? modificationDetails,
    bool clearsPlayedDeclaration = false,
  }) {
    return SavedTicket(
      schemaVersion: schemaVersion,
      id: id,
      source: source ?? this.source,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalOdds: totalOdds ?? this.totalOdds,
      selections: selections ?? this.selections,
      name: name ?? this.name,
      strategyId: strategyId,
      strategyName: strategyName,
      plannedStake: plannedStake ?? this.plannedStake,
      playedDeclaration: clearsPlayedDeclaration
          ? null
          : playedDeclaration ?? this.playedDeclaration,
      mainCombinedReadingId: mainCombinedReadingId,
      mainCombinedReadingLabel: mainCombinedReadingLabel,
      opportunityIds: opportunityIds ?? this.opportunityIds,
      modificationSummary: modificationSummary ?? this.modificationSummary,
      modificationDetails: modificationDetails ?? this.modificationDetails,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'source': source.name,
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'totalOdds': totalOdds,
      'selections': [for (final selection in selections) selection.toJson()],
      'name': name,
      'strategyId': strategyId,
      'strategyName': strategyName,
      'plannedStake': plannedStake,
      'playedDeclaration': playedDeclaration?.toJson(),
      'mainCombinedReadingId': mainCombinedReadingId,
      'mainCombinedReadingLabel': mainCombinedReadingLabel,
      'opportunityIds': opportunityIds,
      'modificationSummary': modificationSummary,
      'modificationDetails': modificationDetails,
    };
  }

  static SavedTicket fromJson(Map<String, Object?> json) {
    final createdAt = _dateValue(json['createdAt']) ?? DateTime.now().toUtc();
    return SavedTicket(
      schemaVersion:
          _intValue(json['schemaVersion']) ?? SavedTicket.currentSchemaVersion,
      id:
          _stringValue(json['id']) ??
          'ticket-${createdAt.microsecondsSinceEpoch}',
      source: _sourceValue(json['source']),
      status: _statusValue(json['status']),
      createdAt: createdAt,
      updatedAt: _dateValue(json['updatedAt']) ?? createdAt,
      totalOdds: _normalizeOdds(_doubleValue(json['totalOdds']) ?? 0),
      selections: [
        for (final selection in _listValue(json['selections']))
          SavedTicketSelection.fromJson(_mapValue(selection)),
      ],
      name: _stringValue(json['name']),
      strategyId: _stringValue(json['strategyId']),
      strategyName: _stringValue(json['strategyName']),
      plannedStake: _doubleValue(json['plannedStake']),
      playedDeclaration: json['playedDeclaration'] == null
          ? null
          : SavedTicketPlayDeclaration.fromJson(
              _mapValue(json['playedDeclaration']),
            ),
      mainCombinedReadingId: _stringValue(json['mainCombinedReadingId']),
      mainCombinedReadingLabel: _stringValue(json['mainCombinedReadingLabel']),
      opportunityIds: [
        for (final id in _listValue(json['opportunityIds']))
          if (_stringValue(id) != null) _stringValue(id)!,
      ],
      modificationSummary: _stringValue(json['modificationSummary']),
      modificationDetails: [
        for (final detail in _listValue(json['modificationDetails']))
          if (_stringValue(detail) != null) _stringValue(detail)!,
      ],
    );
  }

  static SavedTicket fromDraft({
    required TicketDraft draft,
    required String name,
    required DateTime createdAt,
    String? strategyId,
    String? strategyName,
    double? plannedStake,
  }) {
    return SavedTicket(
      schemaVersion: currentSchemaVersion,
      id: 'ticket-${createdAt.microsecondsSinceEpoch}',
      source: SavedTicketSource.manual,
      status: SavedTicketStatus.saved,
      createdAt: createdAt,
      updatedAt: createdAt,
      name: name.trim().isEmpty ? 'Mon ticket' : name.trim(),
      selections: List.unmodifiable([
        for (final selection in draft.selections)
          SavedTicketSelection.fromDraftSelection(selection),
      ]),
      totalOdds: draft.totalOdds,
      strategyId: strategyId,
      strategyName: strategyName,
      plannedStake: plannedStake,
    );
  }

  static SavedTicket fromGenerated({
    required GeneratedTicket ticket,
    required DateTime savedAt,
    List<GeneratedTicketPick>? picks,
    SavedTicketSource? source,
    String? name,
    String? modificationSummary,
    List<String> modificationDetails = const [],
  }) {
    final retainedPicks = picks ?? ticket.picks;
    return SavedTicket(
      schemaVersion: currentSchemaVersion,
      id: 'ticket-${savedAt.microsecondsSinceEpoch}',
      source:
          source ??
          (ticket.origin == TicketOrigin.copilotEdited
              ? SavedTicketSource.copilotModified
              : SavedTicketSource.copilot),
      status: SavedTicketStatus.saved,
      createdAt: savedAt,
      updatedAt: savedAt,
      name: name ?? 'Ticket Lector',
      selections: List.unmodifiable([
        for (final pick in retainedPicks)
          SavedTicketSelection(
            id: [
              pick.matchId,
              pick.marketId,
              pick.selectionId,
              pick.selectionLabel,
            ].join('|'),
            matchId: pick.matchId,
            homeTeam: pick.homeTeam,
            awayTeam: pick.awayTeam,
            competitionName: pick.competitionName,
            marketId: pick.marketId,
            marketLabel: pick.marketLabel,
            selectionId: pick.selectionId,
            selectionLabel: pick.selectionLabel,
            odds: pick.odds,
            opportunityId: pick.opportunityId,
          ),
      ]),
      totalOdds: _totalOdds(retainedPicks.map((pick) => pick.odds)),
      strategyId: ticket.strategyId,
      strategyName: ticket.strategyName,
      mainCombinedReadingId: retainedPicks.firstOrNull?.thesisId,
      opportunityIds: [for (final pick in retainedPicks) pick.opportunityId],
      modificationSummary: modificationSummary,
      modificationDetails: modificationDetails,
    );
  }

  static SavedTicketSelection selectionFromGeneratedPick(
    GeneratedTicketPick pick,
  ) {
    return SavedTicketSelection(
      id: [
        pick.matchId,
        pick.marketId,
        pick.selectionId,
        pick.selectionLabel,
      ].join('|'),
      matchId: pick.matchId,
      homeTeam: pick.homeTeam,
      awayTeam: pick.awayTeam,
      competitionName: pick.competitionName,
      marketId: pick.marketId,
      marketLabel: pick.marketLabel,
      selectionId: pick.selectionId,
      selectionLabel: pick.selectionLabel,
      odds: pick.odds,
      opportunityId: pick.opportunityId,
    );
  }

  static double totalOddsForSelections(
    Iterable<SavedTicketSelection> selections,
  ) {
    return _totalOdds(selections.map((selection) => selection.odds));
  }
}

double _normalizeOdds(double odds) => (odds * 100).round() / 100;

double _totalOdds(Iterable<double> odds) {
  final values = odds.toList();
  if (values.isEmpty) {
    return 0;
  }

  var numerator = BigInt.one;
  var denominator = BigInt.one;
  for (final odd in values) {
    numerator *= BigInt.from((_normalizeOdds(odd) * 100).round());
    denominator *= BigInt.from(100);
  }

  final totalCents = _roundDiv(numerator * BigInt.from(100), denominator);
  return totalCents / 100;
}

int _roundDiv(BigInt numerator, BigInt denominator) {
  final quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator).abs();
  final shouldRoundUp = remainder * BigInt.from(2) >= denominator.abs();
  return (shouldRoundUp ? quotient + BigInt.one : quotient).toInt();
}

String? _stringValue(Object? value) => value?.toString();

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

DateTime? _dateValue(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
}

List<Object?> _listValue(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return const {};
}

SavedTicketSource _sourceValue(Object? value) {
  final name = value?.toString();
  return SavedTicketSource.values.firstWhere(
    (source) => source.name == name,
    orElse: () => SavedTicketSource.manual,
  );
}

SavedTicketStatus _statusValue(Object? value) {
  final name = value?.toString();
  return SavedTicketStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => SavedTicketStatus.saved,
  );
}

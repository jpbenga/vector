import 'dart:math' as math;

import '../../onboarding/domain/decision_profile_catalogs.dart';

class TicketStrategy {
  const TicketStrategy({
    required this.schemaVersion,
    required this.id,
    required this.userId,
    required this.name,
    required this.isActive,
    required this.pickTypes,
    required this.minimumIndividualOdds,
    required this.maximumIndividualOdds,
    required this.minimumSelections,
    required this.maximumSelections,
    required this.minimumTotalOdds,
    required this.maximumTotalOdds,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final String id;
  final String userId;
  final String name;
  final bool isActive;
  final List<PickType> pickTypes;
  final double minimumIndividualOdds;
  final double? maximumIndividualOdds;
  final int minimumSelections;
  final int maximumSelections;
  final double minimumTotalOdds;
  final double? maximumTotalOdds;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  TicketStrategy copyWith({
    String? id,
    String? userId,
    String? name,
    bool? isActive,
    List<PickType>? pickTypes,
    double? minimumIndividualOdds,
    double? maximumIndividualOdds,
    bool clearsMaximumIndividualOdds = false,
    int? minimumSelections,
    int? maximumSelections,
    double? minimumTotalOdds,
    double? maximumTotalOdds,
    bool clearsMaximumTotalOdds = false,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicketStrategy(
      schemaVersion: schemaVersion,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      pickTypes: pickTypes ?? this.pickTypes,
      minimumIndividualOdds:
          minimumIndividualOdds ?? this.minimumIndividualOdds,
      maximumIndividualOdds: clearsMaximumIndividualOdds
          ? null
          : maximumIndividualOdds ?? this.maximumIndividualOdds,
      minimumSelections: minimumSelections ?? this.minimumSelections,
      maximumSelections: maximumSelections ?? this.maximumSelections,
      minimumTotalOdds: minimumTotalOdds ?? this.minimumTotalOdds,
      maximumTotalOdds: clearsMaximumTotalOdds
          ? null
          : maximumTotalOdds ?? this.maximumTotalOdds,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool allowsPickType(PickType pickType) {
    return pickTypes.contains(pickType);
  }

  bool acceptsIndividualOdds(double odds) {
    final normalizedOdds = _normalizeOdds(odds);
    final upperBound = maximumIndividualOdds;

    return normalizedOdds >= minimumIndividualOdds &&
        (upperBound == null || normalizedOdds <= upperBound);
  }

  bool acceptsSelectionCount(int count) {
    return count >= minimumSelections && count <= maximumSelections;
  }

  bool acceptsTotalOdds(double totalOdds) {
    final normalizedTotalOdds = (totalOdds * 100).round() / 100;
    final upperBound = maximumTotalOdds;

    return normalizedTotalOdds >= minimumTotalOdds &&
        (upperBound == null || normalizedTotalOdds <= upperBound);
  }

  bool get hasValidBounds {
    return minimumIndividualOdds >= 1.01 &&
        (maximumIndividualOdds == null ||
            maximumIndividualOdds! >= minimumIndividualOdds) &&
        minimumSelections > 0 &&
        maximumSelections >= minimumSelections &&
        minimumTotalOdds >= 1 &&
        (maximumTotalOdds == null || maximumTotalOdds! >= minimumTotalOdds);
  }

  bool get hasMathematicallyPossibleTicket {
    if (!hasValidBounds) {
      return false;
    }

    final requestedMaximum = maximumTotalOdds ?? double.infinity;
    for (
      var selectionCount = minimumSelections;
      selectionCount <= maximumSelections;
      selectionCount++
    ) {
      final possibleMinimum = math
          .pow(minimumIndividualOdds, selectionCount)
          .toDouble();
      final possibleMaximum = maximumIndividualOdds == null
          ? double.infinity
          : math.pow(maximumIndividualOdds!, selectionCount).toDouble();

      if (possibleMinimum <= requestedMaximum &&
          possibleMaximum >= minimumTotalOdds) {
        return true;
      }
    }

    return false;
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'userId': userId,
      'name': name,
      'isActive': isActive,
      'pickTypes': [for (final pickType in pickTypes) pickType.name],
      'minimumIndividualOdds': minimumIndividualOdds,
      'maximumIndividualOdds': maximumIndividualOdds,
      'minimumSelections': minimumSelections,
      'maximumSelections': maximumSelections,
      'minimumTotalOdds': minimumTotalOdds,
      'maximumTotalOdds': maximumTotalOdds,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static TicketStrategy fromJson(Map<String, Object?> json) {
    final now = DateTime.now().toUtc();
    final legacyPickTypes = [
      for (final value in _listValue(json['pickTypes']))
        if (_pickTypeValue(value) != null) _pickTypeValue(value)!,
    ];
    final minimumIndividualOdds =
        _doubleValue(json['minimumIndividualOdds']) ??
        defaultMinimumIndividualOddsFor(legacyPickTypes);
    final maximumIndividualOdds = json.containsKey('maximumIndividualOdds')
        ? _doubleValue(json['maximumIndividualOdds'])
        : defaultMaximumIndividualOddsFor(legacyPickTypes);
    final pickTypes = legacyPickTypes.isEmpty
        ? pickTypesForIndividualOdds(
            minimumIndividualOdds,
            maximumIndividualOdds,
          )
        : legacyPickTypes;

    return TicketStrategy(
      schemaVersion: _intValue(json['schemaVersion']) ?? currentSchemaVersion,
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: _boolValue(json['isActive']) ?? true,
      pickTypes: pickTypes,
      minimumIndividualOdds: minimumIndividualOdds,
      maximumIndividualOdds: maximumIndividualOdds,
      minimumSelections: _intValue(json['minimumSelections']) ?? 1,
      maximumSelections: _intValue(json['maximumSelections']) ?? 1,
      minimumTotalOdds: _doubleValue(json['minimumTotalOdds']) ?? 1,
      maximumTotalOdds: _doubleValue(json['maximumTotalOdds']),
      priority: _intValue(json['priority']) ?? 1,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  static double defaultMinimumIndividualOddsFor(List<PickType> pickTypes) {
    if (pickTypes.isEmpty) {
      return PickTypeCatalog.prudent.minimumOdds;
    }

    return pickTypes
        .map((pickType) => _bandFor(pickType).minimumOdds)
        .reduce(math.min);
  }

  static double? defaultMaximumIndividualOddsFor(List<PickType> pickTypes) {
    if (pickTypes.isEmpty || pickTypes.contains(PickType.audacious)) {
      return null;
    }

    return pickTypes
        .map((pickType) => _bandFor(pickType).maximumOdds)
        .whereType<double>()
        .reduce(math.max);
  }

  static List<PickType> pickTypesForIndividualOdds(
    double minimumOdds,
    double? maximumOdds,
  ) {
    return [
      for (final pickType in PickType.values)
        if (_bandOverlapsRange(_bandFor(pickType), minimumOdds, maximumOdds))
          pickType,
    ];
  }

  static PickTypeOddsBand _bandFor(PickType pickType) {
    return switch (pickType) {
      PickType.prudent => PickTypeCatalog.prudent,
      PickType.normal => PickTypeCatalog.normal,
      PickType.audacious => PickTypeCatalog.audacious,
    };
  }

  static bool _bandOverlapsRange(
    PickTypeOddsBand band,
    double minimumOdds,
    double? maximumOdds,
  ) {
    final rangeMaximum = maximumOdds ?? double.infinity;
    final bandMaximum = band.maximumOdds ?? double.infinity;

    return minimumOdds <= bandMaximum && rangeMaximum >= band.minimumOdds;
  }
}

List<Object?> _listValue(Object? value) {
  if (value is List<Object?>) {
    return value;
  }

  if (value is List) {
    return value;
  }

  return const [];
}

double? _doubleValue(Object? value) {
  return switch (value) {
    final double number => number,
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
}

int? _intValue(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

bool? _boolValue(Object? value) {
  return switch (value) {
    final bool boolean => boolean,
    final String text => bool.tryParse(text),
    _ => null,
  };
}

PickType? _pickTypeValue(Object? value) {
  final id = value?.toString();
  if (id == null) {
    return null;
  }

  return PickTypeCatalog.byId(id)?.id;
}

double _normalizeOdds(double odds) => (odds * 100).round() / 100;

class OddsRange {
  const OddsRange({required this.min, this.max});

  final double min;
  final double? max;

  String format() {
    final minLabel = min.toStringAsFixed(2);
    final maxValue = max;

    if (maxValue == null) {
      return '$minLabel+';
    }

    return '$minLabel - ${maxValue.toStringAsFixed(2)}';
  }

  Map<String, Object?> toJson() {
    return {'min': min, 'max': max};
  }

  static OddsRange fromJson(Map<String, Object?> json) {
    return OddsRange(
      min: _doubleValue(json['min']) ?? 1,
      max: _doubleValue(json['max']),
    );
  }
}

class OnboardingAnswer {
  const OnboardingAnswer({
    required this.questionId,
    required this.orderedOptionIds,
    this.oddsRanges = const {},
    this.marketMinimumOdds = const {},
    this.scaleValue,
  });

  final String questionId;
  final List<String> orderedOptionIds;
  final Map<String, OddsRange> oddsRanges;
  final Map<String, double> marketMinimumOdds;
  final int? scaleValue;

  OnboardingAnswer copyWith({
    List<String>? orderedOptionIds,
    Map<String, OddsRange>? oddsRanges,
    Map<String, double>? marketMinimumOdds,
    int? scaleValue,
  }) {
    return OnboardingAnswer(
      questionId: questionId,
      orderedOptionIds: orderedOptionIds ?? this.orderedOptionIds,
      oddsRanges: oddsRanges ?? this.oddsRanges,
      marketMinimumOdds: marketMinimumOdds ?? this.marketMinimumOdds,
      scaleValue: scaleValue ?? this.scaleValue,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'questionId': questionId,
      'orderedOptionIds': orderedOptionIds,
      'oddsRanges': {
        for (final entry in oddsRanges.entries) entry.key: entry.value.toJson(),
      },
      'marketMinimumOdds': marketMinimumOdds,
      'scaleValue': scaleValue,
    };
  }

  static OnboardingAnswer fromJson(Map<String, Object?> json) {
    return OnboardingAnswer(
      questionId: json['questionId']?.toString() ?? '',
      orderedOptionIds: [
        for (final id in _listValue(json['orderedOptionIds'])) id.toString(),
      ],
      oddsRanges: {
        for (final entry in _mapValue(json['oddsRanges']).entries)
          entry.key: OddsRange.fromJson(_mapValue(entry.value)),
      },
      marketMinimumOdds: {
        for (final entry in _mapValue(json['marketMinimumOdds']).entries)
          if (_doubleValue(entry.value) != null)
            entry.key: _doubleValue(entry.value)!,
      },
      scaleValue: _intValue(json['scaleValue']),
    );
  }
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

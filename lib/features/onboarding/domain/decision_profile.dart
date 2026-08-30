import 'onboarding_answer.dart';

class DecisionProfile {
  const DecisionProfile({
    required this.onboardingVersion,
    required this.answers,
  });

  final String onboardingVersion;
  final List<OnboardingAnswer> answers;

  DecisionProfile copyWith({
    String? onboardingVersion,
    List<OnboardingAnswer>? answers,
  }) {
    return DecisionProfile(
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      answers: answers ?? this.answers,
    );
  }

  OnboardingAnswer answerFor(String questionId) {
    return answers.firstWhere((answer) => answer.questionId == questionId);
  }

  OnboardingAnswer? optionalAnswerFor(String questionId) {
    for (final answer in answers) {
      if (answer.questionId == questionId) {
        return answer;
      }
    }

    return null;
  }

  List<String> optionIdsFor(String questionId) {
    return optionalAnswerFor(questionId)?.orderedOptionIds ?? const [];
  }

  DecisionProfile withOptionIds(String questionId, List<String> optionIds) {
    final nextAnswer = OnboardingAnswer(
      questionId: questionId,
      orderedOptionIds: List.unmodifiable(optionIds),
    );
    final nextAnswers = [
      for (final answer in answers)
        if (answer.questionId != questionId) answer,
      nextAnswer,
    ];

    return copyWith(answers: List.unmodifiable(nextAnswers));
  }

  Map<String, Object?> toJson() {
    return {
      'onboardingVersion': onboardingVersion,
      'answers': [for (final answer in answers) answer.toJson()],
    };
  }

  static DecisionProfile fromJson(Map<String, Object?> json) {
    return DecisionProfile(
      onboardingVersion: json['onboardingVersion']?.toString() ?? '',
      answers: [
        for (final answer in _listValue(json['answers']))
          OnboardingAnswer.fromJson(_mapValue(answer)),
      ],
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

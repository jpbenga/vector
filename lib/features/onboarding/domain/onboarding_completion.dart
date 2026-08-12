import '../../tickets/domain/ticket_strategy.dart';
import 'decision_profile.dart';

class OnboardingCompletion {
  const OnboardingCompletion({
    required this.profile,
    required this.ticketStrategies,
  });

  final DecisionProfile profile;
  final List<TicketStrategy> ticketStrategies;
}

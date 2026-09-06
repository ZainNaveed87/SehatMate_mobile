import '../data/demo_data.dart';
import 'care_plan_service.dart';
import 'care_reliability_service.dart';

abstract interface class SimpleCareClient {
  Future<CareTaskAppDayData> fetchTodayCare();
  Future<List<DemoPlan>> fetchCarePlans();
  Future<ReliableOutcomeResult> setOutcome(
    CareTaskOccurrence occurrence,
    String status,
  );
}

class SimpleCareService implements SimpleCareClient {
  SimpleCareService._();

  static final SimpleCareService instance = SimpleCareService._();

  @override
  Future<CareTaskAppDayData> fetchTodayCare() {
    return CarePlanService.instance.fetchAllTaskOccurrences();
  }

  @override
  Future<List<DemoPlan>> fetchCarePlans() {
    return CarePlanService.instance.fetchPlans();
  }

  @override
  Future<ReliableOutcomeResult> setOutcome(
    CareTaskOccurrence occurrence,
    String status,
  ) {
    return CareReliabilityService.instance.setOutcome(occurrence, status);
  }
}

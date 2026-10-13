import '../models/app_enums_permissions.dart';
import '../models/app_data_models.dart';
import '../utils/operational_dates.dart';

class LearnedDurationEstimate {
  final Duration duration;
  final String explanation;
  final double confidence;
  final int samples;
  final String basis;
  const LearnedDurationEstimate({required this.duration, required this.explanation, required this.confidence, required this.samples, required this.basis});
}

LearnedDurationEstimate? learnedDurationEstimate(List<CentralizerRecord> records, String locationId, AppSettings settings, {DateTime? targetDate}) {
  final learning = settings.learning['duration'];
  if (learning?.enabled != true) return null;
  final target = targetDate ?? DateTime.now();
  // Folosim doar execuții efective, anterioare zilei estimate.
  // Excludem duratele imposibile și datele lipsă pentru a evita
  // contaminarea Learning-ului cu înregistrări incomplete/viitoare.
  final history = records.where((r) {
    if (r.locationId != locationId || !r.completed || !r.keptForLearning) return false;
    final duration = r.duration;
    if (duration == null || duration.inSeconds <= 0 || duration > const Duration(hours: 24)) return false;
    final event = recordEventTime(r);
    if (event.year <= 1900 || event.isAfter(target)) return false;
    return true;
  }).toList()..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
  if (history.length < 3) return null;
  final sameMonth = history.where((r) => recordEventTime(r).month == target.month).toList();
  final sameWeekday = history.where((r) => recordEventTime(r).weekday == target.weekday).toList();
  List<CentralizerRecord> selected;
  String basis;
  if (sameMonth.length >= 3) {
    selected = sameMonth;
    basis = 'aceeași lună';
  } else if (sameWeekday.length >= 3) {
    selected = sameWeekday;
    basis = 'aceeași zi a săptămânii';
  } else {
    selected = history.length > 12 ? history.sublist(history.length - 12) : history;
    basis = 'istoric recent';
  }

  var seconds = selected.map((r) => r.duration!.inSeconds).where((v) => v > 0).toList()..sort();
  if (seconds.length < 3) return null;
  if (learning!.mode == LearningMode.automatic && seconds.length >= 5) {
    // taie câte o extremă; modelul temporal rămâne stabil la seri atipice
    seconds = seconds.sublist(1, seconds.length - 1);
  }
  final total = seconds.fold<int>(0, (acc, value) => acc + value);
  final average = Duration(seconds: total ~/ seconds.length);
  final spread = seconds.length <= 1 ? 0.0 : (seconds.last - seconds.first) / average.inSeconds.clamp(1, 1 << 30);
  final sampleScore = (seconds.length / 8).clamp(0.0, 1.0).toDouble();
  final stabilityScore = (1.0 - spread.clamp(0.0, 1.0)).toDouble();
  final confidence = (sampleScore * .65 + stabilityScore * .35).clamp(0.0, 1.0).toDouble();
  final explanation = 'Estimare ${durationText(average)} din ${seconds.length} execuții ($basis). '
      '${sameMonth.length >= 3 ? 'Modelul a preferat luna ${target.month}.' : sameWeekday.length >= 3 ? 'Nu au fost 3 mostre în luna curentă; s-a folosit aceeași zi a săptămânii.' : 'Nu au fost suficiente mostre sezoniere; s-a folosit istoricul recent.'}';
  return LearnedDurationEstimate(duration: average, explanation: explanation, confidence: confidence, samples: seconds.length, basis: basis);
}

Duration? learnedAverageDuration(List<CentralizerRecord> records, String locationId, AppSettings settings, {DateTime? targetDate}) =>
    learnedDurationEstimate(records, locationId, settings, targetDate: targetDate)?.duration;


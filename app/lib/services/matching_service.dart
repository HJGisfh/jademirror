import 'dart:math';
import '../models/jade_models.dart';
import '../data/questions.dart';
import '../data/jade_profiles.dart';

Map<String, double> _addVectors(Map<String, double> base, Map<String, double> delta) {
  final result = Map<String, double>.from(base);
  for (final key in delta.keys) {
    result[key] = (result[key] ?? 0) + delta[key]!;
  }
  return result;
}

double cosineSimilarity(Map<String, double> a, Map<String, double> b) {
  double dotProduct = 0;
  double normA = 0;
  double normB = 0;

  for (final key in vectorKeys) {
    final va = a[key] ?? 0;
    final vb = b[key] ?? 0;
    dotProduct += va * vb;
    normA += va * va;
    normB += vb * vb;
  }

  if (normA == 0 || normB == 0) return 0;

  return dotProduct / (sqrt(normA) * sqrt(normB));
}

Map<String, double> computeUserVector(List<Question> questions, Map<String, String> answers) {
  var vector = createZeroVector();

  for (final question in questions) {
    final answerValue = answers[question.id];
    if (answerValue == null) continue;

    final option = question.options.where((o) => o.value == answerValue).firstOrNull;
    if (option == null) continue;

    final delta = option.vector.map((k, v) => MapEntry(k, v.toDouble()));
    vector = _addVectors(vector, delta);
  }

  return vector;
}

String deriveMbtiType(Map<String, double> vector) {
  final letters = [
    (vector['EI'] ?? 0) >= 0 ? 'E' : 'I',
    (vector['SN'] ?? 0) >= 0 ? 'S' : 'N',
    (vector['TF'] ?? 0) >= 0 ? 'T' : 'F',
    (vector['JP'] ?? 0) >= 0 ? 'J' : 'P',
  ];
  return letters.join('');
}

ArchetypeResult getDominantArchetype(Map<String, double> vector) {
  const labelMap = {
    'Warrior': '战士',
    'Sage': '智者',
    'Explorer': '探索者',
    'Mediator': '调停者',
    'Creator': '创造者',
    'Ruler': '统治者',
    'Healer': '治愈者',
  };

  String best = 'Sage';
  double bestVal = double.negativeInfinity;

  for (final key in archetypeDims) {
    final val = vector[key] ?? 0;
    if (val > bestVal) {
      bestVal = val;
      best = key;
    }
  }

  return ArchetypeResult(key: best, label: labelMap[best] ?? best, score: bestVal);
}

DimensionScores computeDimensionScores(Map<String, double> vector) {
  const maxPossible = 8.0;

  final mbti = <String, DimensionScore>{};
  for (final key in mbtiDims) {
    final val = vector[key] ?? 0;
    final absVal = val.abs();
    final percent = min(100, (absVal / maxPossible * 100).round());
    final dominantMap = {
      'EI': val >= 0 ? 'E' : 'I',
      'SN': val >= 0 ? 'S' : 'N',
      'TF': val >= 0 ? 'T' : 'F',
      'JP': val >= 0 ? 'J' : 'P',
    };
    mbti[key] = DimensionScore(value: val, percent: percent, dominant: dominantMap[key] ?? '');
  }

  final big5 = <String, DimensionScore>{};
  for (final key in big5Dims) {
    final val = vector[key] ?? 0;
    final normalized = (val + maxPossible) / (2 * maxPossible);
    final percent = min(100, max(0, (normalized * 100).round()));
    big5[key] = DimensionScore(value: val, percent: percent, dominant: '');
  }

  final archetypes = <String, DimensionScore>{};
  for (final key in archetypeDims) {
    final val = vector[key] ?? 0;
    final percent = min(100, max(0, (val / maxPossible * 100).round()));
    archetypes[key] = DimensionScore(value: val, percent: percent, dominant: '');
  }

  return DimensionScores(mbti: mbti, big5: big5, archetypes: archetypes);
}

List<FlowchartStep> deriveFlowchartPath(
  List<Question> questions,
  Map<String, String> answers,
  Map<String, double> vector,
  JadeProfile? profile,
) {
  final steps = <FlowchartStep>[];
  final moduleAnswers = <String, List<_ModuleAnswer>>{};

  for (final question in questions) {
    final answerValue = answers[question.id];
    if (answerValue == null) continue;
    final option = question.options.where((o) => o.value == answerValue).firstOrNull;
    if (option == null) continue;

    moduleAnswers.putIfAbsent(question.module, () => []);
    moduleAnswers[question.module]!.add(_ModuleAnswer(
      questionId: question.id,
      label: option.label,
      moduleTitle: question.moduleTitle,
    ));
  }

  for (final entry in moduleAnswers.entries) {
    steps.add(FlowchartStep(
      type: 'module',
      moduleKey: entry.key,
      moduleTitle: entry.value.first.moduleTitle,
      choices: entry.value.map((i) => i.label).toList(),
    ));
  }

  final mbtiType = deriveMbtiType(vector);
  steps.add(FlowchartStep(type: 'mbti', label: mbtiType));

  final archetype = getDominantArchetype(vector);
  steps.add(FlowchartStep(type: 'archetype', label: archetype.label));

  steps.add(FlowchartStep(
    type: 'jade',
    label: profile != null ? profile.archetypeLabel : '古玉',
  ));

  return steps;
}

MatchResult matchJadeByVector({
  required List<JadeItem> jades,
  required Map<String, double> userVector,
}) {
  if (jades.isEmpty) {
    throw Exception('玉器库为空，无法执行匹配。');
  }

  final scores = <_JadeScore>[];

  for (final jade in jades) {
    final profile = getJadeProfile(jade.id);
    if (profile == null) continue;

    final similarity = cosineSimilarity(userVector, profile.vector);
    scores.add(_JadeScore(jade: jade, profile: profile, similarity: similarity));
  }

  scores.sort((a, b) => b.similarity.compareTo(a.similarity));

  final best = scores.first;
  final worst = scores.last;

  final mbtiType = deriveMbtiType(userVector);
  final archetype = getDominantArchetype(userVector);
  final dimensionScores = computeDimensionScores(userVector);

  return MatchResult(
    jade: best.jade,
    profile: best.profile,
    score: best.similarity,
    mbtiType: mbtiType,
    archetype: archetype,
    dimensionScores: dimensionScores,
    shadowJade: worst.jade,
    shadowProfile: worst.profile,
    allScores: scores
        .map((s) => JadeScoreEntry(
              jadeId: s.jade.id,
              jadeName: s.jade.name,
              similarity: s.similarity,
            ))
        .toList(),
  );
}

class _ModuleAnswer {
  final String questionId;
  final String label;
  final String moduleTitle;

  const _ModuleAnswer({
    required this.questionId,
    required this.label,
    required this.moduleTitle,
  });
}

class _JadeScore {
  final JadeItem jade;
  final JadeProfile profile;
  final double similarity;

  const _JadeScore({
    required this.jade,
    required this.profile,
    required this.similarity,
  });
}

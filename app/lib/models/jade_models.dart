class JadeTraits {
  final String landscape;
  final String color;
  final String symbol;
  final String mood;
  final String texture;

  const JadeTraits({
    required this.landscape,
    required this.color,
    required this.symbol,
    required this.mood,
    required this.texture,
  });

  factory JadeTraits.fromJson(Map<String, dynamic> json) => JadeTraits(
        landscape: json['landscape'] as String? ?? '',
        color: json['color'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        mood: json['mood'] as String? ?? '',
        texture: json['texture'] as String? ?? '',
      );
}

class AudioParams {
  final int baseFreq;
  final String waveform;
  final String filterType;
  final int filterFreq;
  final double attack;
  final double decay;

  const AudioParams({
    required this.baseFreq,
    required this.waveform,
    required this.filterType,
    required this.filterFreq,
    required this.attack,
    required this.decay,
  });

  factory AudioParams.fromJson(Map<String, dynamic> json) => AudioParams(
        baseFreq: json['baseFreq'] as int,
        waveform: json['waveform'] as String,
        filterType: json['filterType'] as String,
        filterFreq: json['filterFreq'] as int,
        attack: (json['attack'] as num).toDouble(),
        decay: (json['decay'] as num).toDouble(),
      );
}

class JadeItem {
  final int id;
  final String name;
  final String dynasty;
  final String description;
  final String personality;
  final String image;
  final JadeTraits traits;
  final AudioParams audioParams;

  const JadeItem({
    required this.id,
    required this.name,
    required this.dynasty,
    required this.description,
    required this.personality,
    required this.image,
    required this.traits,
    required this.audioParams,
  });

  factory JadeItem.fromJson(Map<String, dynamic> json) => JadeItem(
        id: json['id'] as int,
        name: json['name'] as String,
        dynasty: json['dynasty'] as String,
        description: json['description'] as String,
        personality: json['personality'] as String,
        image: json['image'] as String,
        traits: JadeTraits.fromJson(json['traits'] as Map<String, dynamic>),
        audioParams:
            AudioParams.fromJson(json['audioParams'] as Map<String, dynamic>),
      );

  String get svgAssetName {
    final fileName = image.split('/').last;
    return fileName;
  }
}

class JadeProfile {
  final int id;
  final String mbtiType;
  final String archetype;
  final String archetypeLabel;
  final Map<String, double> vector;
  final String verdict;
  final PsychologyInfo psychology;
  final String shadowBlindSpot;
  final int shadowJadeId;
  final String shadowAdvice;

  const JadeProfile({
    required this.id,
    required this.mbtiType,
    required this.archetype,
    required this.archetypeLabel,
    required this.vector,
    required this.verdict,
    required this.psychology,
    required this.shadowBlindSpot,
    required this.shadowJadeId,
    required this.shadowAdvice,
  });
}

class PsychologyInfo {
  final String coreEnergy;
  final String baseColor;

  const PsychologyInfo({
    required this.coreEnergy,
    required this.baseColor,
  });
}

class ArchetypeResult {
  final String key;
  final String label;
  final double score;

  const ArchetypeResult({
    required this.key,
    required this.label,
    required this.score,
  });
}

class DimensionScore {
  final double value;
  final int percent;
  final String dominant;

  const DimensionScore({
    required this.value,
    required this.percent,
    required this.dominant,
  });
}

class DimensionScores {
  final Map<String, DimensionScore> mbti;
  final Map<String, DimensionScore> big5;
  final Map<String, DimensionScore> archetypes;

  const DimensionScores({
    required this.mbti,
    required this.big5,
    required this.archetypes,
  });
}

class FlowchartStep {
  final String type;
  final String? moduleKey;
  final String? moduleTitle;
  final List<String>? choices;
  final String? label;

  const FlowchartStep({
    required this.type,
    this.moduleKey,
    this.moduleTitle,
    this.choices,
    this.label,
  });
}

class MatchResult {
  final JadeItem jade;
  final JadeProfile profile;
  final double score;
  final String mbtiType;
  final ArchetypeResult archetype;
  final DimensionScores dimensionScores;
  final JadeItem shadowJade;
  final JadeProfile shadowProfile;
  final List<JadeScoreEntry> allScores;

  const MatchResult({
    required this.jade,
    required this.profile,
    required this.score,
    required this.mbtiType,
    required this.archetype,
    required this.dimensionScores,
    required this.shadowJade,
    required this.shadowProfile,
    required this.allScores,
  });
}

class JadeScoreEntry {
  final int jadeId;
  final String jadeName;
  final double similarity;

  const JadeScoreEntry({
    required this.jadeId,
    required this.jadeName,
    required this.similarity,
  });
}

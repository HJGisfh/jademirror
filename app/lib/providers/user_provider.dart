import 'package:flutter/material.dart';
import '../models/jade_models.dart';
import '../data/questions.dart';
import '../services/matching_service.dart';
import '../services/jade_library_service.dart';

class UserProvider extends ChangeNotifier {
  String _testMode = '';
  Map<String, String> _testAnswers = {};
  Map<String, double> _userVector = createZeroVector();
  JadeItem? _matchedJade;
  JadeProfile? _matchProfile;
  double _matchScore = 0;
  String _mbtiType = '';
  ArchetypeResult? _archetype;
  DimensionScores? _dimensionScores;
  JadeItem? _shadowJade;
  JadeProfile? _shadowProfile;
  List<FlowchartStep> _flowchartPath = [];
  List<JadeScoreEntry> _allScores = [];

  bool _isLoading = false;
  String? _error;

  String get testMode => _testMode;
  Map<String, String> get testAnswers => _testAnswers;
  Map<String, double> get userVector => _userVector;
  JadeItem? get matchedJade => _matchedJade;
  JadeProfile? get matchProfile => _matchProfile;
  double get matchScore => _matchScore;
  String get mbtiType => _mbtiType;
  ArchetypeResult? get archetype => _archetype;
  DimensionScores? get dimensionScores => _dimensionScores;
  JadeItem? get shadowJade => _shadowJade;
  JadeProfile? get shadowProfile => _shadowProfile;
  List<FlowchartStep> get flowchartPath => _flowchartPath;
  List<JadeScoreEntry> get allScores => _allScores;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasMatchedJade => _matchedJade != null;
  bool get hasRequiredAnswers => _testAnswers.isNotEmpty;

  int get answeredCount => _testAnswers.length;

  List<Question> get currentQuestions {
    if (_testMode == 'quick') return quickTestQuestions;
    return deepTestQuestions;
  }

  int get totalQuestions => currentQuestions.length;

  void setTestMode(String mode) {
    _testMode = mode;
    _testAnswers = {};
    _userVector = createZeroVector();
    notifyListeners();
  }

  void setAnswer(String questionId, String value) {
    _testAnswers[questionId] = value;
    notifyListeners();
  }

  void clearAnswers() {
    _testAnswers = {};
    _userVector = createZeroVector();
    notifyListeners();
  }

  Future<void> computeAndMatch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userVector = computeUserVector(currentQuestions, _testAnswers);

      final jadeLibrary = JadeLibraryService();
      final jades = await jadeLibrary.loadJades();

      final result = matchJadeByVector(jades: jades, userVector: _userVector);

      _matchedJade = result.jade;
      _matchProfile = result.profile;
      _matchScore = result.score;
      _mbtiType = result.mbtiType;
      _archetype = result.archetype;
      _dimensionScores = result.dimensionScores;
      _shadowJade = result.shadowJade;
      _shadowProfile = result.shadowProfile;
      _allScores = result.allScores;

      _flowchartPath = deriveFlowchartPath(
        currentQuestions,
        _testAnswers,
        _userVector,
        _matchProfile,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetTest() {
    _testMode = '';
    _testAnswers = {};
    _userVector = createZeroVector();
    _matchedJade = null;
    _matchProfile = null;
    _matchScore = 0;
    _mbtiType = '';
    _archetype = null;
    _dimensionScores = null;
    _shadowJade = null;
    _shadowProfile = null;
    _flowchartPath = [];
    _allScores = [];
    _error = null;
    notifyListeners();
  }
}

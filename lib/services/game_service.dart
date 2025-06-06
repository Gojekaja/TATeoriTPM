import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import '../models/quiz_question.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'dart:async';

class GameService {
  static final GameService _instance = GameService._internal();
  late final GenerativeModel _geminiModel;
  final Random _random = Random();
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  // Game state
  int _currentLevel = 1;
  QuizQuestion? _currentQuestion;
  final Set<String> _usedPowerUps = {};
  bool _isGameActive = false;
  static const List<int> checkpointLevels = [3, 6, 9];

  // Double Prize Event state
  bool _isDoublePrizeEventActive = false;
  double _currentDoublePrizeAmount = 0.0;
  bool _shakeDetected = false;
  double _lastShakeMagnitude = 0.0;
  bool _canVibrate = false;
  Timer? _continuousVibrationTimer;

  // Shake detection settings
  static const double _shakeThreshold = 25.0;
  static const int _shakeCoolDownMs = 1000;
  DateTime _lastShakeTime = DateTime.now();
  DateTime _lastVibrateTime = DateTime.now();

  factory GameService() {
    return _instance;
  }

  GameService._internal() {
    _initializeGemini();
    _initAccelerometerListener();
    _initVibration();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _geminiModel = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<void> _initVibration() async {
    _canVibrate = await Vibration.hasVibrator() ?? false;
    if (_canVibrate) {
      bool? hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      debugPrint('Device has amplitude control: $hasAmplitudeControl');
    }
  }

  // Game state getters
  int get currentLevel => _currentLevel;
  bool get isGameActive => _isGameActive;
  List<String> get usedPowerUps => _usedPowerUps.toList();
  bool get isAtCheckpoint => checkpointLevels.contains(_currentLevel);
  AuthService get authService => _authService;

  // Double Prize Event getters
  bool get isDoublePrizeEventActive => _isDoublePrizeEventActive;
  double get currentDoublePrizeAmount => _currentDoublePrizeAmount;
  bool get shakeDetected => _shakeDetected;

  void _initAccelerometerListener() {
    accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(
      (AccelerometerEvent event) {
        final double magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );

        if (_isDoublePrizeEventActive &&
            DateTime.now().difference(_lastShakeTime).inMilliseconds >
                _shakeCoolDownMs) {
          if (magnitude > _shakeThreshold) {
            _shakeDetected = true;
            _lastShakeMagnitude = magnitude;
            _lastShakeTime = DateTime.now();
            _vibrateOnShakeDetected();
            debugPrint('Guncangan terdeteksi! Magnitude: $magnitude');
          } else if (!_shakeDetected &&
              magnitude >
                  _shakeThreshold *
                      0.7 && // Threshold for "almost there" feedback
              DateTime.now().difference(_lastVibrateTime).inMilliseconds >
                  500) {
            // Vibration cooldown
            _vibrateForProgress();
          }
        }
      },
      onError: (e) {
        debugPrint('Error mengakses accelerometer: $e');
      },
      cancelOnError: true,
    );
  }

  // Vibration feedback methods
  Future<void> _vibrateOnShakeDetected() async {
    if (!_canVibrate) return;

    // Super intense success pattern with multiple vibrations
    for (int i = 0; i < 2; i++) {
      await Vibration.vibrate(
        pattern: [0, 50, 50, 50, 50, 50], // Vibration pattern
        intensities: [255, 255, 255, 255, 255, 255], // Full intensity
        amplitude: 255, // Maximum amplitude
        repeat: 0, // Repeat only once
      );
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // Final strong vibration
    await Vibration.vibrate(
      pattern: [0, 500], // Start immediately, vibrate for 500ms
      intensities: [255], // Maximum intensity
      repeat: 0, // Start repeating from index 0
    );
  }

  Future<void> _vibrateForProgress() async {
    if (!_canVibrate) return;
    _lastVibrateTime = DateTime.now();

    // Triple burst for progress
    await Vibration.vibrate(
      pattern: [0, 300, 300, 300], // Start immediately, vibrate for 300ms each
      intensities: [255, 255, 255], // Full intensity
      repeat: 0, // Start repeating from index 0
    );
  }

  // Vibrate when double prize event starts
  Future<void> vibrateForEventStart() async {
    if (!_canVibrate) return;

    // Strong initial pattern
    await Vibration.vibrate(
      pattern: [0, 500, 100, 500, 100, 500], // Alternating vibration and pause
      intensities: [255, 0, 255, 0, 255], // Full intensity when vibrating
      amplitude: 255, // Maximum amplitude
    );
  }

  // Start new game
  Future<void> startGame() async {
    _currentLevel = 1;
    _usedPowerUps.clear();
    _isGameActive = true;
    _isDoublePrizeEventActive = false;
    _currentDoublePrizeAmount = 0.0;
    _shakeDetected = false;
  }

  // Public methods for vibration control
  void stopContinuousVibration() {
    if (!_canVibrate) return;
    Vibration.cancel();
  }

  void startContinuousVibration() async {
    if (!_canVibrate) return;

    // Initial intense burst
    await Vibration.vibrate(
      pattern: [0, 300], // Start immediately, vibrate for 300ms
      intensities: [255], // Maximum intensity
      repeat: 0, // Start repeating from index 0
    );
  }

  // Handle correct answer with continuous vibration
  Future<void> handleCorrectAnswer() async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User tidak terdaftar');

    _usedPowerUps.clear();

    if (checkpointLevels.contains(_currentLevel) || _currentLevel == 12) {
      final reward = calculateReward(_currentLevel);

      if (_shouldTriggerDoublePrizeEvent(_currentLevel)) {
        _isDoublePrizeEventActive = true;
        _currentDoublePrizeAmount = reward * 2;
        _shakeDetected = false;

        // Start continuous vibration
        startContinuousVibration();

        debugPrint(
          'Event Ganda Terdeteksi untuk Level $_currentLevel! Jumlah: $_currentDoublePrizeAmount',
        );
      } else {
        user.dolarBalance += reward;
        user.purchaseHistory.add(
          PurchaseHistory(
            type: 'Game Win',
            amount: reward,
            date: DateTime.now(),
            item: 'Kamu menang level $_currentLevel !',
            price: '${reward.toStringAsFixed(0)} Dolar',
          ),
        );
        debugPrint('Hadiah normal untuk Level $_currentLevel. Jumlah: $reward');
      }
    }

    _currentLevel++;

    await _db.gameStatsBox.put('${user.username}_stats', {
      'highestLevel': max(
        _currentLevel - 1,
        (_db.gameStatsBox.get('${user.username}_stats')?['highestLevel'] ?? 0)
            as int,
      ),
      'totalWinnings':
          ((_db.gameStatsBox.get('${user.username}_stats')?['totalWinnings'] ??
                      0)
                  as num)
              .toDouble(),
      'lastPlayed': DateTime.now().toIso8601String(),
    });

    await user.save();
  }

  // Claim double prize with cleanup
  Future<bool> claimDoublePrize() async {
    if (!_isDoublePrizeEventActive || !_shakeDetected) {
      debugPrint(
        'Tidak dapat mengklaim hadiah ganda: Event tidak aktif atau guncangan tidak terdeteksi.',
      );
      return false;
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    user.dolarBalance += _currentDoublePrizeAmount;
    user.purchaseHistory.add(
      PurchaseHistory(
        type: 'Game Win (Double Prize)',
        amount: _currentDoublePrizeAmount,
        date: DateTime.now(),
        item: 'Double Prize for Level ${_currentLevel - 1}!',
        price: '${_currentDoublePrizeAmount.toStringAsFixed(0)} Dolar',
      ),
    );

    await _db.gameStatsBox.put('${user.username}_stats', {
      'highestLevel': max(
        _currentLevel - 1,
        (_db.gameStatsBox.get('${user.username}_stats')?['highestLevel'] ?? 0)
            as int,
      ),
      'totalWinnings':
          ((_db.gameStatsBox.get('${user.username}_stats')?['totalWinnings'] ??
                      0)
                  as num)
              .toDouble() +
          _currentDoublePrizeAmount,
      'lastPlayed': DateTime.now().toIso8601String(),
    });

    _isDoublePrizeEventActive = false;
    _currentDoublePrizeAmount = 0.0;
    _shakeDetected = false;
    _lastShakeMagnitude = 0.0;

    // Stop continuous vibration
    stopContinuousVibration();

    await user.save();
    debugPrint('Hadiah Ganda Terklaim! Jumlah: ${user.dolarBalance}');
    return true;
  }

  // Skip double prize event with cleanup
  Future<void> skipDoublePrizeEvent() async {
    if (!_isDoublePrizeEventActive) {
      debugPrint('Tidak ada event ganda untuk dilewatkan.');
      return;
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User tidak terdaftar');

    final regularPrizeAmount = _currentDoublePrizeAmount / 2;
    user.dolarBalance += regularPrizeAmount;
    user.purchaseHistory.add(
      PurchaseHistory(
        type: 'Game Win',
        amount: regularPrizeAmount,
        date: DateTime.now(),
        item: 'Regular Prize for Level ${_currentLevel - 1}',
        price: '${regularPrizeAmount.toStringAsFixed(0)} Dolar',
      ),
    );

    await _db.gameStatsBox.put('${user.username}_stats', {
      'highestLevel': max(
        _currentLevel - 1,
        (_db.gameStatsBox.get('${user.username}_stats')?['highestLevel'] ?? 0)
            as int,
      ),
      'totalWinnings':
          ((_db.gameStatsBox.get('${user.username}_stats')?['totalWinnings'] ??
                      0)
                  as num)
              .toDouble() +
          regularPrizeAmount,
      'lastPlayed': DateTime.now().toIso8601String(),
    });

    _isDoublePrizeEventActive = false;
    _currentDoublePrizeAmount = 0.0;
    _shakeDetected = false;
    _lastShakeMagnitude = 0.0;

    // Stop continuous vibration
    stopContinuousVibration();

    await user.save();
    debugPrint(
      'Event Ganda dilewatkan. Hadiah normal ditambahkan: $regularPrizeAmount',
    );
  }

  // Take money at checkpoint
  Future<bool> takeMoney(double amount) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check for double prize opportunity when taking money
    if (_shouldTriggerDoublePrizeEvent(_currentLevel)) {
      _isDoublePrizeEventActive = true;
      _currentDoublePrizeAmount = amount * 2;
      _shakeDetected = false;
      return true; // Indicate that double prize event is triggered
    }

    // If no double prize event, proceed with normal money collection
    await _finalizeMoneyCollection(amount);
    return false; // Indicate no double prize event
  }

  // Helper method to finalize money collection
  Future<void> _finalizeMoneyCollection(double amount) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    _isDoublePrizeEventActive = false;
    _currentDoublePrizeAmount = 0.0;
    _shakeDetected = false;
    _lastShakeMagnitude = 0.0;

    user.dolarBalance += amount;
    user.purchaseHistory.add(
      PurchaseHistory(
        type: 'Game Win',
        amount: amount,
        date: DateTime.now(),
        item: 'Kamu menang level $_currentLevel !',
        price: '${amount.toStringAsFixed(0)} Dolar',
      ),
    );

    await _db.gameStatsBox.put('${user.username}_stats', {
      'highestLevel': max(
        _currentLevel,
        (_db.gameStatsBox.get('${user.username}_stats')?['highestLevel'] ?? 0)
            as int,
      ),
      'totalWinnings':
          ((_db.gameStatsBox.get('${user.username}_stats')?['totalWinnings'] ??
                      0)
                  as num)
              .toDouble() +
          amount,
      'lastPlayed': DateTime.now().toIso8601String(),
    });

    _isGameActive = false;
    await user.save();
  }

  // Determine if double prize event should trigger
  bool _shouldTriggerDoublePrizeEvent(int level) {
    if (level == 3) {
      return _random.nextInt(100) < 70; // 70% chance at first checkpoint
    } else if (level == 6) {
      return _random.nextInt(100) < 50; // 50% chance at second checkpoint
    } else if (level == 9) {
      return _random.nextInt(100) < 30; // 30% chance at third checkpoint
    } else if (level == 12) {
      return _random.nextInt(100) < 20; // 20% chance at final level
    }
    return false;
  }

  // Handle game over
  Future<void> handleGameOver({bool saveCheckpoint = false}) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    _isGameActive = false;
    _isDoublePrizeEventActive = false;
    _currentDoublePrizeAmount = 0.0;
    _shakeDetected = false;
    await user.save();
  }

  // Calculate reward for current level
  double calculateReward(int level) {
    switch (level) {
      case 1:
        return 100;
      case 2:
        return 200;
      case 3:
        return 400;
      case 4:
        return 800;
      case 5:
        return 1600;
      case 6:
        return 3200;
      case 7:
        return 6400;
      case 8:
        return 12500;
      case 9:
        return 25000;
      case 10:
        return 50000;
      case 11:
        return 250000;
      case 12:
        return 1000000;
      default:
        return 0;
    }
  }

  // Power-up: 50:50
  Future<Map<String, String>> applyFiftyFifty(
    Map<String, String> options,
    String correctKey,
  ) async {
    if (_usedPowerUps.contains('50_50')) {
      throw Exception('50:50 Sudah terpakai');
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    if (user.powerUpStats.fiftyFiftyUsed <= 0) {
      throw Exception('tidak ada 50:50 power-ups tersedia');
    }

    // Use power-up
    user.powerUpStats.fiftyFiftyUsed--;
    _usedPowerUps.add('50_50');

    // Remove two wrong answers
    List<String> wrongKeys = options.keys
        .where((key) => key != correctKey)
        .toList();
    wrongKeys.shuffle();
    wrongKeys = wrongKeys.sublist(0, 2);

    Map<String, String> newOptions = Map.from(options);
    for (var key in wrongKeys) {
      newOptions.remove(key);
    }

    await user.save();
    return newOptions;
  }

  // Power-up: Call Friend
  Future<String> getCallFriendAdvice(
    String questionText,
    Map<String, String> options,
    String correctKey,
  ) async {
    if (_usedPowerUps.contains('call_friend')) {
      throw Exception('Teman Anda sudah digunakan dalam pertanyaan ini');
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    if (user.powerUpStats.callFriendUsed <= 0) {
      throw Exception('tidak ada telpon teman power-ups tersedia');
    }

    // Use power-up
    user.powerUpStats.callFriendUsed--;
    _usedPowerUps.add('call_friend');

    // Get the correct answer text
    final correctAnswerText = _currentQuestion?.options[correctKey] ?? '';

    // Generate advice
    final isTruthful = _random.nextInt(100) >= 65;
    final prompt = isTruthful
        ? "Berikan saran yang mengarah pada jawaban yang benar yaitu '$correctAnswerText' tetapi dengan ketidakpastian. Jawab dalam Bahasa Indonesia yang santai, tidak terlalu panjang dan ala gen z."
        : "Berikan saran yang menyesatkan tetapi jangan menyebutkan '$correctAnswerText' sebagai jawaban. Jawab dalam Bahasa Indonesia yang santai, tidak terlalu panjang dan ala gen z.";

    try {
      final content = [Content.text(prompt)];
      final response = await _geminiModel.generateContent(content);
      await user.save();
      return "Teman Anda mengatakan: ${response.text ?? 'Maaf, saya tidak yakin tentang yang satu ini.'}";
    } catch (e) {
      await user.save();
      return "Teman Anda tidak dapat dihubungi.";
    }
  }

  // Power-up: Ask Audience
  Future<Map<String, int>> getAudienceVote(String correctKey) async {
    if (_usedPowerUps.contains('audience')) {
      throw Exception('Tanya Audience sudah digunakan dalam pertanyaan ini');
    }

    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    if (user.powerUpStats.audienceUsed <= 0) {
      throw Exception('tidak ada tanya audience power-ups tersedia');
    }

    // Use power-up
    user.powerUpStats.audienceUsed--;
    _usedPowerUps.add('audience');

    // Generate audience votes
    Map<String, int> votes = {'A': 0, 'B': 0, 'C': 0, 'D': 0};

    // Correct answer gets 15-35%
    votes[correctKey] = 20 + _random.nextInt(21);

    // Distribute remaining votes
    int remaining = 100 - votes[correctKey]!;
    List<String> otherKeys = votes.keys
        .where((key) => key != correctKey)
        .toList();
    otherKeys.shuffle();

    for (int i = 0; i < otherKeys.length; i++) {
      if (i == otherKeys.length - 1) {
        votes[otherKeys[i]] = remaining;
      } else {
        int vote = _random.nextInt(remaining ~/ (otherKeys.length - i));
        votes[otherKeys[i]] = vote;
        remaining -= vote;
      }
    }

    await user.save();
    return votes;
  }

  // Generate a question for the current level
  Future<QuizQuestion> generateQuestion({required int level}) async {
    try {
      final prompt =
          """
      Buat pertanyaan 'Who Wants to Be a Millionaire?' untuk Level $level.

      Format:
      Pertanyaan: [Teks]
      A. [Pilihan]
      B. [Pilihan]
      C. [Pilihan]
      D. [Pilihan]
      Benar: [Huruf]
      Kategori: [Kategori]
      Subkategori: [Subkategori]
      Tingkat Kesulitan: [$level]

      Persyaratan:
      - Kesulitan pertanyaan harus sesuai dengan level (1-12)
      - Pilihan jawaban yang salah harus masuk akal tetapi jelas salah
      - Untuk Level 7 ke atas, sertakan pengetahuan yang lebih menantang/spesifik
      - **Seluruh output harus dalam Bahasa Indonesia.**
      """;

      final content = [Content.text(prompt)];
      final response = await _geminiModel.generateContent(content);
      final text = response.text;

      if (text != null) {
        return _parseQuestionResponse(text);
      }
      throw Exception('gagal membuat pertanyaan');
    } catch (e) {
      debugPrint("Error generating question: $e");
      throw Exception('Failed to generate question');
    }
  }

  QuizQuestion _parseQuestionResponse(String text) {
    final lines = text.split('\n').where((line) => line.isNotEmpty).toList();
    String questionText = "";
    Map<String, String> options = {};
    String correctAnswerKey = "";
    String correctAnswerText = "";
    String category = "";
    String subcategory = "";
    int difficultyLevel = 0;

    for (var line in lines) {
      if (line.startsWith('Pertanyaan:')) {
        questionText = line.substring('Pertanyaan:'.length).trim();
      } else if (line.startsWith('A.')) {
        options['A'] = line.substring('A.'.length).trim();
      } else if (line.startsWith('B.')) {
        options['B'] = line.substring('B.'.length).trim();
      } else if (line.startsWith('C.')) {
        options['C'] = line.substring('C.'.length).trim();
      } else if (line.startsWith('D.')) {
        options['D'] = line.substring('D.'.length).trim();
      } else if (line.startsWith('Benar:')) {
        correctAnswerKey = line.substring('Benar:'.length).trim();
      } else if (line.startsWith('Kategori:')) {
        category = line.substring('Kategori:'.length).trim();
      } else if (line.startsWith('Subkategori:')) {
        subcategory = line.substring('Subkategori:'.length).trim();
      } else if (line.startsWith('Tingkat Kesulitan:')) {
        difficultyLevel =
            int.tryParse(line.substring('Tingkat Kesulitan:'.length).trim()) ??
            0;
      }
    }

    // Get the correct answer text from options
    correctAnswerText = options[correctAnswerKey] ?? '';

    return QuizQuestion(
      id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      questionText: questionText,
      options: options,
      correctAnswerKey: correctAnswerKey,
      correctAnswerText: correctAnswerText,
      category: category,
      subcategory: subcategory,
      difficultyLevel: difficultyLevel,
    );
  }

  // Di GameService
  Future<QuizQuestion> getNextQuestion() async {
    try {
      final question = await generateQuestion(level: _currentLevel);
      _currentQuestion = question;
      return question;
    } catch (e) {
      debugPrint("Error fetching question: $e");
      throw Exception('Failed to get next question');
    }
  }

  Future<GameResult> checkAnswer(String questionId, String answer) async {
    if (_currentQuestion == null) {
      throw Exception('No active question');
    }

    if (_currentQuestion!.id != questionId) {
      throw Exception('Question ID mismatch');
    }

    final isCorrect = _currentQuestion!.correctAnswerKey == answer;
    final earnedAmount = calculateReward(_currentLevel);
    final isGameComplete = _currentLevel == 12 && isCorrect;

    if (isCorrect && !isGameComplete) {
      _currentLevel++;
    }

    return GameResult(
      isCorrect: isCorrect,
      earnedAmount: earnedAmount,
      isGameComplete: isGameComplete,
    );
  }

  double calculateEarnings() {
    // Define prize amounts for each level
    const prizes = [
      100,
      200,
      400,
      800,
      1600,
      200,
      6400,
      12500,
      25000,
      50000,
      250000,
      1000000,
    ];

    // Return prize for current level - 1 (since _currentLevel starts at 1)
    return _currentLevel <= 1 ? 0 : prizes[_currentLevel - 2].toDouble();
  }

  @override
  void dispose() {
    stopContinuousVibration();
  }
}

class GameResult {
  final bool isCorrect;
  final double earnedAmount;
  final bool isGameComplete;

  GameResult({
    required this.isCorrect,
    required this.earnedAmount,
    required this.isGameComplete,
  });
}

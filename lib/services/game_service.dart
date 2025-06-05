import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/quiz_question.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'database_service.dart';

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

  factory GameService() {
    return _instance;
  }

  GameService._internal() {
    _initializeGemini();
  }

  void _initializeGemini() {
    const apiKey = 'AIzaSyD_GaXj6lpJlwxItrubZncWxGgJDKq9ryg';
    _geminiModel = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  // Game state getters
  int get currentLevel => _currentLevel;
  bool get isGameActive => _isGameActive;
  List<String> get usedPowerUps => _usedPowerUps.toList();
  bool get isAtCheckpoint => checkpointLevels.contains(_currentLevel);
  AuthService get authService => _authService;

  // Take money at checkpoint
  Future<void> takeMoney(double amount) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Add the amount to user's balance
    user.dolarBalance += amount;

    // Add to purchase history with new format
    user.purchaseHistory.add(
      PurchaseHistory(
        type: 'Game Win',
        amount: amount,
        date: DateTime.now(),
        item: 'You win level $_currentLevel !',
        price: '${amount.toStringAsFixed(0)} Dolar',
      ),
    );

    // Save game stats
    await _db.gameStatsBox.put('${user.username}_stats', {
      'highestLevel': max(
        _currentLevel,
        (_db.gameStatsBox.get('${user.username}_stats')?['highestLevel'] ?? 0)
            as int,
      ),
      'totalWinnings':
          ((_db.gameStatsBox.get('${user.username}_stats')?['totalWinnings'] ??
                  0)
              as double) +
          amount,
      'lastPlayed': DateTime.now().toIso8601String(),
    });

    // Reset game state
    _isGameActive = false;
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

  // Start new game
  Future<void> startGame() async {
    _currentLevel = 1;
    _usedPowerUps.clear();
    _isGameActive = true;
  }

  // Handle correct answer
  Future<void> handleCorrectAnswer() async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Only add reward at checkpoints or final level
    if (checkpointLevels.contains(_currentLevel - 1) ||
        _currentLevel - 1 == 12) {
      // Calculate reward for the previous level
      final reward = calculateReward(_currentLevel - 1);
      user.dolarBalance += reward;

      // Add to purchase history with new format
      user.purchaseHistory.add(
        PurchaseHistory(
          type: 'Game Win',
          amount: reward,
          date: DateTime.now(),
          item: 'You win level ${_currentLevel - 1} !',
          price: '${reward.toStringAsFixed(0)} Dolar',
        ),
      );
    }

    // Save game stats with proper type conversion
    await _db.gameStatsBox.put('${user.username}_stats', {
      'highestLevel': max(
        _currentLevel,
        (_db.gameStatsBox.get('${user.username}_stats')?['highestLevel'] ?? 0)
            as int,
      ),
      'totalWinnings':
          (((_db.gameStatsBox.get('${user.username}_stats')?['totalWinnings'] ??
                  0) as num)
              .toDouble()) +
          (checkpointLevels.contains(_currentLevel - 1) ||
                  _currentLevel - 1 == 12
              ? calculateReward(_currentLevel - 1)
              : 0),
      'lastPlayed': DateTime.now().toIso8601String(),
    });

    _usedPowerUps.clear();

    await user.save();
  }

  // Handle game over
  Future<void> handleGameOver({bool saveCheckpoint = false}) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    _isGameActive = false;
    await user.save();
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

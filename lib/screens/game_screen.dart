import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/quiz_question.dart';
import '../services/game_service.dart';
import '../utils/currency_converter.dart';
import '../widgets/confetti_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Gunakan GameService sebagai singleton
  final GameService _gameService = GameService();

  QuizQuestion? _currentQuestion;
  Map<String, String> _displayOptions = {};
  bool _isLoading = false;
  String _message = "Siap menjadi miliarder?";
  bool _isCelebrating = false;
  String? _selectedAnswer;
  bool _canAnswer = true;

  // Enhanced animations
  late AnimationController _questionAnimController;
  late AnimationController _optionsAnimController;
  late AnimationController _pulseAnimController;
  late Animation<double> _questionAnimation;
  late Animation<double> _optionsAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startGame();
  }

  void _setupAnimations() {
    // Question slide-in animation
    _questionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _questionAnimation = CurvedAnimation(
      parent: _questionAnimController,
      curve: Curves.elasticOut,
    );

    // Options stagger animation
    _optionsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _optionsAnimation = CurvedAnimation(
      parent: _optionsAnimController,
      curve: Curves.easeOutBack,
    );

    // Pulse animation for money amount
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );
    _pulseAnimController.repeat(reverse: true);
  }

  Future<void> _startGame() async {
    setState(() {
      _isLoading = true;
      _message = "Memulai permainan baru...";
      _isCelebrating = false;
    });

    try {
      await _gameService.startGame();
      await _loadNextQuestion();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = "Error memulai permainan: $e";
      });
    }
  }

  Future<void> _checkAnswer(String key) async {
    if (!_canAnswer || _selectedAnswer != null) return;

    setState(() {
      _selectedAnswer = key;
      _canAnswer = false;
    });

    try {
      if (_currentQuestion == null) {
        throw Exception(
          "Tidak ada pertanyaan saat ini untuk memeriksa jawaban.",
        );
      }
      final result = await _gameService.checkAnswer(_currentQuestion!.id, key);

      if (!mounted) return;

      if (!result.isCorrect) {
        setState(() {
          _message = "Wrong answer! Game Over!";
        });
        await _gameService.handleGameOver(
          saveCheckpoint: _gameService.isAtCheckpoint,
        );
        _showGameOverDialog(result.earnedAmount);
        return;
      }

      // Handle correct answer
      await _gameService.handleCorrectAnswer();

      setState(() {
        _message = "Benar! Pindah ke level berikutnya!";
        // Only show confetti when completing level 12
        _isCelebrating = _gameService.currentLevel == 12;
      });

      if (result.isGameComplete) {
        _showVictoryDialog(result.earnedAmount);
        return;
      }

      // Check if player reached a checkpoint
      if (_gameService.isAtCheckpoint) {
        _showCheckpointDialog(result.earnedAmount);
        return;
      }

      // Load next question after delay
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _loadNextQuestion();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Error memeriksa jawaban: $e";
      });
    }
  }

  Future<void> _loadNextQuestion() async {
    try {
      final question = await _gameService.getNextQuestion();
      if (!mounted) return;

      setState(() {
        _currentQuestion = question;
        _displayOptions = question.options;
        _selectedAnswer = null;
        _canAnswer = true;
        _message = "Pilih jawaban dengan hati-hati!";
      });

      _questionAnimController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 300));
      _optionsAnimController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Error memuat pertanyaan berikutnya: $e";
      });
    }
  }

  // --- Power-Up Logic ---
  Future<void> _usePowerUp(String powerUpType) async {
    if (_currentQuestion == null || !_canAnswer) {
      setState(() {
        _message =
            "Tidak dapat menggunakan power-up sekarang. Silakan jawab pertanyaan saat ini";
      });
      return;
    }

    // Add this guard:
    if (_gameService.authService.currentUser == null) {
      setState(() {
        _message =
            "Anda belum login. Silakan login untuk menggunakan power-up.";
      });
      return;
    }

    // Simpan kunci jawaban yang benar untuk digunakan oleh power-up
    String originalCorrectKey = _currentQuestion!.correctAnswerKey;
    Map<String, String> originalOptions = Map.from(_currentQuestion!.options);

    try {
      switch (powerUpType) {
        case '50_50':
          final newOptions = await _gameService.applyFiftyFifty(
            originalOptions,
            originalCorrectKey,
          );
          setState(() {
            _displayOptions = newOptions; // Perbarui opsi yang ditampilkan
            _message = "50:50 power-up digunakan! Dua jawaban salah dihapus.";
          });
          break;
        case 'call_friend':
          final advice = await _gameService.getCallFriendAdvice(
            _currentQuestion!.questionText,
            originalOptions,
            originalCorrectKey,
          );
          setState(() {
            _message = advice; // Tampilkan saran dari teman
          });
          break;
        case 'audience':
          final votes = await _gameService.getAudienceVote(originalCorrectKey);
          String voteMessage = "Audience votes:\n";
          votes.forEach((key, value) {
            voteMessage += "$key: $value% ";
          });
          setState(() {
            _message = voteMessage;
          });
          break;
        default:
          setState(() {
            _message = "Power-up tidak dikenal.";
          });
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _message = "Power-up gagal: ${e.toString()}";
      });
    }
  }

  void _showGameOverDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Main Lagi?',
          style: GoogleFonts.poppins(
            color: Colors.red[400],
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[400]?.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.sentiment_dissatisfied_rounded,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Kamu gagal mendapatkan ',
              style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyConverter.formatGameDolar(amount),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/store');
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Kunjungi Toko",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startGame();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Main Lagi",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVictoryDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Congratulations!',
          style: GoogleFonts.poppins(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Kamu adalah seorang miliarder!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Total Winnings:',
              style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyConverter.formatGameDolar(amount),
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startGame();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Main Lagi",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckpointDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sampai cek poin!',
          style: GoogleFonts.poppins(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Kamu telah mencapai level ${_gameService.currentLevel}!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Hadiah saat ini :',
              style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyConverter.formatGameDolar(amount),
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Apakah kamu ingin mengambil uang atau melanjutkan bermain?',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    // Save the current amount to user's balance
                    await _gameService.takeMoney(amount);
                    if (!mounted) return;
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mahal king 🔥🔥! ${CurrencyConverter.formatGameDolar(amount)} sudah ditambahkan ke saldo Anda',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Restart the game
                    _startGame();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Ambil Uang",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _loadNextQuestion();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Lanjut",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _questionAnimController.dispose();
    _optionsAnimController.dispose();
    _pulseAnimController.dispose();
    super.dispose();
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A), // Slate 900
            const Color(0xFF1E293B), // Slate 800
            const Color(0xFF334155), // Slate 700
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Level and Money Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LEVEL",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_gameService.currentLevel}",
                    style: GoogleFonts.poppins(
                      color: Colors.amber,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "HADIAH SAAT INI",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      // Pastikan currentLevel - 1 tidak negatif
                      final prizeLevel = _gameService.currentLevel > 1
                          ? _gameService.currentLevel - 1
                          : 1;
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Text(
                          _gameService.calculateReward(prizeLevel).toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.amber,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress bar with gradient
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [Colors.grey[850]!, Colors.grey[700]!],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _gameService.currentLevel / 12,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _gameService.currentLevel == 12
                            ? Colors.purple
                            : Colors.amber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Enhanced level indicators
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final spacing =
                          (availableWidth - (24 * 12)) /
                          11; // Calculate dynamic spacing

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(12, (index) {
                          final level = index + 1;
                          final isCheckpoint = GameService.checkpointLevels
                              .contains(level);
                          final isActive = level <= _gameService.currentLevel;
                          final isCurrent = level == _gameService.currentLevel;
                          final isFinalLevel = level == 12;

                          // Adjust sizes to be smaller
                          final baseSize = isFinalLevel
                              ? 28.0
                              : (isCheckpoint ? 24.0 : 20.0);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: baseSize,
                            height: baseSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _getIndicatorGradient(
                                level,
                                isActive,
                                isCurrent,
                                isCheckpoint,
                                isFinalLevel,
                              ),
                              border: _getIndicatorBorder(
                                level,
                                isActive,
                                isCurrent,
                                isCheckpoint,
                                isFinalLevel,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: isFinalLevel
                                            ? Colors.purple.withOpacity(0.4)
                                            : isCheckpoint
                                            ? Colors.green.withOpacity(0.4)
                                            : Colors.amber.withOpacity(0.4),
                                        blurRadius: isCurrent ? 8 : 4,
                                        spreadRadius: isCurrent ? 2 : 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isFinalLevel && isActive)
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Colors.white,
                                    size: 14, // Reduced from 16
                                  )
                                else if (isCheckpoint && isActive)
                                  Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: isCheckpoint
                                        ? 12
                                        : 10, // Reduced sizes
                                  )
                                else
                                  Text(
                                    '$level',
                                    style: GoogleFonts.poppins(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.grey[400],
                                      fontSize: isFinalLevel
                                          ? 10
                                          : (isCheckpoint
                                                ? 9
                                                : 8), // Reduced font sizes
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                if (isCurrent)
                                  Container(
                                    width: baseSize + 6, // Reduced from +8
                                    height: baseSize + 6, // Reduced from +8
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isFinalLevel
                                            ? Colors.purple.withOpacity(0.6)
                                            : Colors.amber.withOpacity(0.6),
                                        width: 1.5, // Reduced from 2
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to add to your widget class:
  LinearGradient _getIndicatorGradient(
    int level,
    bool isActive,
    bool isCurrent,
    bool isCheckpoint,
    bool isFinalLevel,
  ) {
    if (!isActive) {
      return LinearGradient(
        colors: [Colors.grey[700]!, Colors.grey[800]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    if (isFinalLevel) {
      return const LinearGradient(
        colors: [Colors.purple, Colors.deepPurple],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    if (isCheckpoint) {
      return const LinearGradient(
        colors: [Colors.green, Colors.teal],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    return LinearGradient(
      colors: [Colors.amber, Colors.orange[600]!],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  Border? _getIndicatorBorder(
    int level,
    bool isActive,
    bool isCurrent,
    bool isCheckpoint,
    bool isFinalLevel,
  ) {
    if (!isActive) return null;

    if (isFinalLevel) {
      return Border.all(color: Colors.purple[300]!, width: 2);
    }

    if (isCheckpoint) {
      return Border.all(color: Colors.green[300]!, width: 2);
    }

    return null;
  }

  Widget _buildQuestionCard() {
    if (_currentQuestion == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
      );
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_questionAnimation),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[850]!, Colors.grey[800]!],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Text(
                _currentQuestion!.category.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Question text
            Text(
              _currentQuestion!.questionText,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerGrid() {
    return AnimatedBuilder(
      animation: _optionsAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _optionsAnimation.value,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _displayOptions.entries.map((entry) {
                final index = _displayOptions.keys.toList().indexOf(entry.key);
                final isSelected = entry.key == _selectedAnswer;
                final isCorrect =
                    _currentQuestion?.correctAnswerKey == entry.key;
                final showResult = _selectedAnswer != null;

                Color backgroundColor = const Color(0xFF374151); // Gray 700
                Color borderColor = Colors.transparent;

                if (showResult) {
                  if (isSelected) {
                    backgroundColor = isCorrect
                        ? Colors.green[600]!
                        : Colors.red[600]!;
                  } else if (isCorrect) {
                    backgroundColor = Colors.green[600]!;
                  }
                } else if (isSelected) {
                  backgroundColor = Colors.blue[600]!;
                }

                return Container(
                  margin: EdgeInsets.only(bottom: index < 3 ? 16 : 0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _canAnswer ? () => _checkAnswer(entry.key) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: backgroundColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  entry.key,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Text(
        _message,
        style: GoogleFonts.poppins(
          color: Colors.amber,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Who Wants to Be a Millionaire?',
          style: GoogleFonts.poppins(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Tombol Power-Up (menggunakan PopupMenuButton)
          PopupMenuButton<String>(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.amber),
            tooltip: 'Gunakan Power-Up',
            onSelected: (String result) {
              _usePowerUp(result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Opsi 50:50
              PopupMenuItem<String>(
                value: '50_50',
                enabled:
                    !_gameService.usedPowerUps.contains('50_50') &&
                    (_gameService
                                .authService
                                .currentUser
                                ?.powerUpStats
                                .fiftyFiftyUsed ??
                            0) >
                        0,
                child: Text(
                  '50:50 (${_gameService.authService.currentUser?.powerUpStats.fiftyFiftyUsed ?? 0})',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
              // Opsi Call Friend
              PopupMenuItem<String>(
                value: 'call_friend',
                enabled:
                    !_gameService.usedPowerUps.contains('call_friend') &&
                    (_gameService
                                .authService
                                .currentUser
                                ?.powerUpStats
                                .callFriendUsed ??
                            0) >
                        0,
                child: Text(
                  'Call Friend (${_gameService.authService.currentUser?.powerUpStats.callFriendUsed ?? 0})',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
              // Opsi Ask Audience
              PopupMenuItem<String>(
                value: 'audience',
                enabled:
                    !_gameService.usedPowerUps.contains('audience') &&
                    (_gameService
                                .authService
                                .currentUser
                                ?.powerUpStats
                                .audienceUsed ??
                            0) >
                        0,
                child: Text(
                  'Ask Audience (${_gameService.authService.currentUser?.powerUpStats.audienceUsed ?? 0})',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
            color: Colors.grey[850], // Warna latar belakang pop-up
          ),

          // Tombol Reset Game
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.amber),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    'Restart Permainan?',
                    style: GoogleFonts.poppins(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  content: Text(
                    'Apakah kamu yakin ingin memulai ulang permainan? Progres saat ini akan hilang.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _isCelebrating = false;
                        });
                        _startGame(); // Memulai ulang game
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(
                        'Restart',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Restart Game',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          if (_isCelebrating) const ConfettiOverlay(),
          SafeArea(
            child: _isLoading && _currentQuestion == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 3,
                    ),
                  )
                : ListView(
                    children: [
                      _buildHeader(),
                      _buildQuestionCard(),
                      _buildAnswerGrid(),
                      _buildStatusMessage(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

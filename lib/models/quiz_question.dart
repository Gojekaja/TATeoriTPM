class QuizQuestion {
  final String id;
  final String questionText;
  final Map<String, String> options; // e.g., {'A': 'Option A', 'B': 'Option B'}
  final String correctAnswerKey; // e.g., 'B'
  final String correctAnswerText;
  final String category;
  final String subcategory;
  final int difficultyLevel;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerKey,
    required this.correctAnswerText,
    required this.category,
    required this.subcategory,
    required this.difficultyLevel,
  });

  // Factory constructor to create a question from Gemini API response
  factory QuizQuestion.fromGeminiResponse(String response) {
    try {
      final lines = response
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList();
      String questionText = "";
      Map<String, String> options = {};
      String correctAnswerKey = "";
      String correctAnswerText = "";
      String category = "";
      String subcategory = "";
      int difficultyLevel = 0;

      for (var line in lines) {
        if (line.startsWith('Question:')) {
          questionText = line.substring('Question:'.length).trim();
        } else if (line.startsWith('A.')) {
          options['A'] = line.substring('A.'.length).trim();
        } else if (line.startsWith('B.')) {
          options['B'] = line.substring('B.'.length).trim();
        } else if (line.startsWith('C.')) {
          options['C'] = line.substring('C.'.length).trim();
        } else if (line.startsWith('D.')) {
          options['D'] = line.substring('D.'.length).trim();
        } else if (line.startsWith('Correct:')) {
          correctAnswerKey = line.substring('Correct:'.length).trim();
        } else if (line.startsWith('Correct Answer:')) {
          correctAnswerText = line.substring('Correct Answer:'.length).trim();
        } else if (line.startsWith('Category:')) {
          category = line.substring('Category:'.length).trim();
        } else if (line.startsWith('Subcategory:')) {
          subcategory = line.substring('Subcategory:'.length).trim();
        } else if (line.startsWith('Difficulty:')) {
          difficultyLevel =
              int.tryParse(line.substring('Difficulty:'.length).trim()) ?? 0;
        }
      }

      if (questionText.isEmpty ||
          options.length != 4 ||
          correctAnswerKey.isEmpty) {
        throw const FormatException('Invalid question format');
      }

      return QuizQuestion(
        id: "",
        questionText: questionText,
        options: options,
        correctAnswerKey: correctAnswerKey,
        correctAnswerText: correctAnswerText,
        category: category,
        subcategory: subcategory,
        difficultyLevel: difficultyLevel,
      );
    } catch (e) {
      // Return a fallback question if parsing fails
      return QuizQuestion(
        id: "",
        questionText: "Failed to load. Here's a sample:\nWhat is 2+2?",
        options: {'A': '3', 'B': '4', 'C': '5', 'D': '6'},
        correctAnswerKey: 'B',
        correctAnswerText: '4',
        category: "Sample",
        subcategory: "Sample",
        difficultyLevel: 0,
      );
    }
  }

  // Helper method to get category display text
  String getCategoryDisplay() {
    if (category == 'Mixed') {
      return 'Mixed ($subcategory)';
    }
    return '$category ($subcategory)';
  }
}

// Define available categories and subcategories
class QuizCategories {
  static const Map<String, List<String>> categories = {
    'Technology': ['AI', 'Gadgets', 'Programming'],
    'Entertainment': ['Movies', 'Games', 'Music'],
    'Science': ['Physics', 'Astronomy', 'Biology'],
    'Lifestyle': ['Travel', 'Food', 'Health'],
    'Mixed': [], // Will be dynamically generated
  };

  static String getRandomSubcategory(String category) {
    if (category == 'Mixed') {
      // For mixed, combine two random categories
      final mainCategories = categories.keys
          .where((k) => k != 'Mixed')
          .toList();
      mainCategories.shuffle();
      return '${mainCategories[0]} + ${mainCategories[1]}';
    }

    final subcategories = categories[category]!;
    subcategories.shuffle();
    return subcategories.first;
  }
}

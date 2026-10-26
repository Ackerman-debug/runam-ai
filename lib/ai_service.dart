import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _baseUrl = 'http://localhost:11434/api/generate';

  Future<String> generateResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemma3:1b',
          'prompt': prompt,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No response generated.';
      } else {
        return 'Error: Status code ${response.statusCode}';
      }
    } catch (e) {
      return 'Failed to connect to local Ollama service: $e';
    }
  }

  /// Generates a structured JSON quiz using Ollama's native JSON mode
  Future<List<Map<String, dynamic>>> generateQuiz(String sourceText) async {
    final systemPrompt = '''
Generate 5 multiple-choice questions for the topic or text: "$sourceText".

You MUST output ONLY a valid JSON object matching this schema exactly:
{
  "questions": [
    {
      "question": "What is the primary function of telecommunication systems?",
      "options": ["Transmitting information over distances", "Storing local power", "Generating physical force", "Filtering light"],
      "correctLetter": "A",
      "explanation": "Telecommunications involves transmitting information across significant distances using electronic signals."
    }
  ]
}
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemma3:1b',
          'prompt': systemPrompt,
          'format': 'json',
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawJsonText = data['response'] as String;
        final decoded = jsonDecode(rawJsonText);

        List rawList = [];
        if (decoded is Map && decoded.containsKey('questions')) {
          rawList = decoded['questions'] as List;
        } else if (decoded is List) {
          rawList = decoded;
        }

        return rawList.map((item) {
          final map = Map<String, dynamic>.from(item);
          final options = List<String>.from(map['options'] ?? []);

          int answerIndex = 0;
          if (map.containsKey('correctLetter')) {
            final letter = map['correctLetter'].toString().trim().toUpperCase();
            if (letter.isNotEmpty) {
              answerIndex = letter.codeUnitAt(0) - 65;
            }
          } else if (map.containsKey('answerIndex')) {
            answerIndex = map['answerIndex'] as int;
          }

          if (answerIndex < 0 || answerIndex >= options.length) {
            answerIndex = 0;
          }

          map['answerIndex'] = answerIndex;
          return map;
        }).toList();
      } else {
        throw Exception('Status code ${response.statusCode}');
      }
    } catch (e) {
      return [
        {
          "question": "Quiz Generation Error for '$sourceText': $e",
          "options": ["Retry Request", "Check Ollama Server", "Verify Model Load", "Inspect Terminal"],
          "answerIndex": 0,
          "explanation": "Local service could not parse structured JSON response."
        }
      ];
    }
  }

  /// Generates 5 study flashcard pairs (Front/Back) using native JSON mode
  Future<List<Map<String, String>>> generateFlashcards(String sourceText) async {
    final systemPrompt = '''
Generate 5 study flashcards (concept and definition) for the topic or text: "$sourceText".

You MUST output ONLY a valid JSON object matching this schema exactly:
{
  "flashcards": [
    {
      "front": "Bandwidth",
      "back": "The maximum rate of data transfer across a network path per second."
    }
  ]
}
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemma3:1b',
          'prompt': systemPrompt,
          'format': 'json',
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawJsonText = data['response'] as String;
        final decoded = jsonDecode(rawJsonText);

        List rawList = [];
        if (decoded is Map && decoded.containsKey('flashcards')) {
          rawList = decoded['flashcards'] as List;
        } else if (decoded is List) {
          rawList = decoded;
        }

        return rawList.map((item) {
          final map = Map<String, dynamic>.from(item);
          return {
            'front': map['front']?.toString() ?? 'Concept',
            'back': map['back']?.toString() ?? 'Definition',
          };
        }).toList();
      } else {
        throw Exception('Status code ${response.statusCode}');
      }
    } catch (e) {
      return [
        {
          'front': 'Error generating flashcards',
          'back': 'Could not parse response for "$sourceText": $e',
        }
      ];
    }
  }

  /// Generates structured executive summaries and key takeaway points
  Future<String> generateSummary(String sourceText) async {
    final systemPrompt = '''
You are an expert study assistant. Provide a structured summary of the text or topic below.

Structure your response using clean Markdown with the following sections:
- **TL;DR**: A 2-sentence core summary.
- **Key Takeaways**: 3-5 bullet points highlighting critical concepts.
- **Core Terminology**: Key terms defined concisely.

Topic or Text to Summarize:
$sourceText
''';

    return await generateResponse(systemPrompt);
  }
}
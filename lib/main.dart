import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'ai_service.dart';

void main() {
  runApp(const RunAmApp());
}

class RunAmApp extends StatelessWidget {
  const RunAmApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2563EB);
    const backgroundColor = Color(0xFF0F172A);
    const surfaceColor = Color(0xFF1E293B);

    return MaterialApp(
      title: 'RunAm AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          surface: surfaceColor,
          onSurface: Color(0xFFF8FAFC),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const MainLayoutScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();

  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _quizQuestions = [];
  Map<int, int> _selectedAnswers = {};

  List<Map<String, String>> _flashcards = [];
  int _currentCardIndex = 0;
  bool _showCardBack = false;

  String _activeSection = 'Assistant';
  String? _attachedFileName;
  String? _attachedFileContent;
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachedFileContent == null) return;
    if (_isLoading) return;

    _controller.clear();

    if (_activeSection == 'Quiz Generator') {
      setState(() {
        _isLoading = true;
        _quizQuestions.clear();
        _selectedAnswers.clear();
      });

      final sourceText = _attachedFileContent ?? text;
      final questions = await _aiService.generateQuiz(sourceText);

      setState(() {
        _quizQuestions = questions;
        _isLoading = false;
        _attachedFileName = null;
        _attachedFileContent = null;
      });
    } else if (_activeSection == 'Flashcards') {
      setState(() {
        _isLoading = true;
        _flashcards.clear();
        _currentCardIndex = 0;
        _showCardBack = false;
      });

      final sourceText = _attachedFileContent ?? text;
      final cards = await _aiService.generateFlashcards(sourceText);

      setState(() {
        _flashcards = cards;
        _isLoading = false;
        _attachedFileName = null;
        _attachedFileContent = null;
      });
    } else if (_activeSection == 'Summarizer') {
      setState(() {
        _isLoading = true;
      });

      final sourceText = _attachedFileContent ?? text;
      final summary = await _aiService.generateSummary(sourceText);

      setState(() {
        _messages.add(ChatMessage(text: summary, isUser: false));
        _isLoading = false;
        _attachedFileName = null;
        _attachedFileContent = null;
      });  
    } else {
      String finalPrompt = text;
      if (_attachedFileContent != null) {
        finalPrompt = "Document Context ($_attachedFileName):\n$_attachedFileContent\n\nUser Question:\n$text";
      }

      setState(() {
        _messages.add(ChatMessage(
          text: text.isEmpty ? "Analyzed document: $_attachedFileName" : text,
          isUser: true,
        ));
        _isLoading = true;
      });

      _scrollToBottom();

      final reply = await _aiService.generateResponse(finalPrompt);

      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isLoading = false;
        _attachedFileName = null;
        _attachedFileContent = null;
      });

      _scrollToBottom();
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'json', 'csv', 'pdf', 'docx'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        final content = utf8.decode(file.bytes!);

        setState(() {
          _attachedFileName = file.name;
          _attachedFileContent = content;
        });
      }
    }
  }

  void _clearState() {
    if (_isLoading) return;
    setState(() {
      _messages.clear();
      _quizQuestions.clear();
      _selectedAnswers.clear();
      _flashcards.clear();
      _currentCardIndex = 0;
      _showCardBack = false;
      _attachedFileName = null;
      _attachedFileContent = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RunAm AI — $_activeSection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear State',
            onPressed: (_messages.isEmpty && _quizQuestions.isEmpty && _flashcards.isEmpty) || _isLoading
                ? null
                : _clearState,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1E293B)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('RunAm Suite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Engine: Gemma 3 1B (Local)', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            _buildDrawerTile('Assistant', Icons.chat_bubble_outline),
            _buildDrawerTile('Quiz Generator', Icons.quiz_outlined),
            _buildDrawerTile('Flashcards', Icons.style_outlined),
            _buildDrawerTile('Summarizer', Icons.summarize_outlined),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _activeSection == 'Quiz Generator'
                ? _buildQuizView()
                : (_activeSection == 'Flashcards'
                    ? _buildFlashcardView()
                    : _buildChatView()),
          ),
          if (_attachedFileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Attached: $_attachedFileName',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFF8FAFC)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _attachedFileName = null;
                      _attachedFileContent = null;
                    }),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF94A3B8)),
                    tooltip: 'Attach local file (.txt, .md, .csv, .pdf, .docx)',
                    onPressed: _isLoading ? null : _pickFile,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isLoading,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(fontSize: 14, color: Color(0xFFF8FAFC)),
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'Gemma 3 processing...'
                            : (_activeSection == 'Quiz Generator'
                                ? 'Enter topic or attach text to generate quiz...'
                                : (_activeSection == 'Flashcards'
                                    ? 'Enter topic or attach text to generate flashcards...'
                                    : (_activeSection == 'Summarizer'
                                        ? 'Enter topic or attach document to generate a summary...'
                                        : 'Type a prompt...'))),
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          // REPLACE THE Text WIDGET INSIDE _buildChatView() WITH THIS:

        child: Text(
          _activeSection == 'Summarizer'
              ? 'Summarizer ready. Attach a document or type a topic to summarize.'
              : 'Assistant ready. Attach a text/markdown file or type a prompt.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),

        ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: msg.isUser ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(16),
                bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(2),
              ),
            ),
            child: SelectableText(
              msg.text,
              style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFFF8FAFC)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizView() {
    if (_quizQuestions.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Text(
            'Quiz Mode active. Type a topic or attach study notes to generate MCQs.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quizQuestions.length,
      itemBuilder: (context, qIndex) {
        final q = _quizQuestions[qIndex];
        final options = List<String>.from(q['options'] ?? []);
        final correctIdx = q['answerIndex'] as int?;
        final selectedIdx = _selectedAnswers[qIndex];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q${qIndex + 1}. ${q['question']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC)),
              ),
              const SizedBox(height: 12),
              ...List.generate(options.length, (oIndex) {
                final isSelected = selectedIdx == oIndex;
                final isCorrect = oIndex == correctIdx;

                Color tileColor = const Color(0xFF0F172A);
                Color borderColor = const Color(0xFF334155);

                if (selectedIdx != null) {
                  if (isCorrect) {
                    tileColor = const Color(0xFF065F46);
                    borderColor = const Color(0xFF10B981);
                  } else if (isSelected && !isCorrect) {
                    tileColor = const Color(0xFF991B1B);
                    borderColor = const Color(0xFFEF4444);
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (selectedIdx == null) {
                      setState(() {
                        _selectedAnswers[qIndex] = oIndex;
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Text(
                          String.fromCharCode(65 + oIndex) + '.',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            options[oIndex],
                            style: const TextStyle(fontSize: 14, color: Color(0xFFF8FAFC)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (selectedIdx != null && q['explanation'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Explanation: ${q['explanation']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlashcardView() {
    if (_flashcards.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Text(
            'Flashcards Mode active. Type a topic or attach notes to generate a deck.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
        ),
      );
    }

    final card = _flashcards[_currentCardIndex];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Index Header
          Text(
            'Card ${_currentCardIndex + 1} of ${_flashcards.length}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Flip Card
          GestureDetector(
            onTap: () {
              setState(() {
                _showCardBack = !_showCardBack;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: 260,
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _showCardBack ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showCardBack ? 'DEFINITION / ANSWER' : 'CONCEPT / QUESTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: _showCardBack ? const Color(0xFF94A3B8) : const Color(0xFF93C5FD),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _showCardBack ? card['back']! : card['front']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Click to flip card',
                        style: TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Control Arrows & Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _currentCardIndex > 0
                    ? () {
                        setState(() {
                          _currentCardIndex--;
                          _showCardBack = false;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _currentCardIndex < _flashcards.length - 1
                    ? () {
                        setState(() {
                          _currentCardIndex++;
                          _showCardBack = false;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(String title, IconData icon) {
    final isSelected = _activeSection == title;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() => _activeSection = title);
        Navigator.pop(context);
      },
    );
  }
}
import 'package:flutter/material.dart';

/// Insurance Literacy Quiz — gamified learning about policy terms.
///
/// Helps users understand insurance concepts through:
/// - Key terms glossary with simple explanations
/// - Interactive quiz based on their uploaded policies
/// - Progress tracking
class InsuranceLiteracyScreen extends StatefulWidget {
  const InsuranceLiteracyScreen({super.key});

  @override
  State<InsuranceLiteracyScreen> createState() => _InsuranceLiteracyScreenState();
}

class _InsuranceLiteracyScreenState extends State<InsuranceLiteracyScreen> {
  int _currentQuizIndex = 0;
  int _score = 0;
  bool _quizStarted = false;
  bool _quizFinished = false;
  bool _showingExplanation = false;
  bool _lastAnswerCorrect = false;

  static const _terms = [
    _Term(
      term: 'Premium',
      definition: 'The amount you pay (usually monthly or annually) to keep your insurance policy active.',
      icon: Icons.payments,
    ),
    _Term(
      term: 'Deductible',
      definition: 'The amount you pay out of pocket before your insurance starts covering costs.',
      icon: Icons.receipt_long,
    ),
    _Term(
      term: 'Sum Insured',
      definition: 'The maximum amount your insurer will pay for a covered claim.',
      icon: Icons.shield,
    ),
    _Term(
      term: 'Waiting Period',
      definition: 'The time after buying a policy when certain conditions are not yet covered.',
      icon: Icons.hourglass_top,
    ),
    _Term(
      term: 'Exclusion',
      definition: 'Conditions, treatments, or situations that your policy does NOT cover.',
      icon: Icons.block,
    ),
    _Term(
      term: 'Cashless Claim',
      definition: "Your insurer pays the hospital directly — you don't pay upfront (for network hospitals).",
      icon: Icons.credit_card,
    ),
    _Term(
      term: 'Reimbursement Claim',
      definition: 'You pay first, then submit bills to your insurer to get paid back.',
      icon: Icons.replay,
    ),
    _Term(
      term: 'Floater Policy',
      definition: 'A single policy that covers your entire family under one sum insured.',
      icon: Icons.family_restroom,
    ),
    _Term(
      term: 'No Claim Bonus (NCB)',
      definition: 'A discount or increased coverage you earn for not making a claim in a year.',
      icon: Icons.star,
    ),
    _Term(
      term: 'Pre-existing Disease',
      definition: 'Any health condition you had before buying the policy. Usually has a longer waiting period.',
      icon: Icons.medical_services,
    ),
    _Term(
      term: 'Co-payment',
      definition: 'A fixed percentage of the claim amount that you pay yourself (e.g., 10% of ₹1 lakh = ₹10,000).',
      icon: Icons.percent,
    ),
    _Term(
      term: 'Restoration Benefit',
      definition: 'If your sum insured is exhausted, this benefit restores it (fully or partially) for the same year.',
      icon: Icons.refresh,
    ),
  ];

  static const _quizQuestions = [
    _QuizQuestion(
      question: 'What is the amount you pay out of pocket before insurance kicks in?',
      options: ['Premium', 'Deductible', 'Sum Insured', 'Co-payment'],
      correctIndex: 1,
      explanation: 'The deductible is your out-of-pocket amount before insurance coverage begins.',
    ),
    _QuizQuestion(
      question: 'A floater policy covers:',
      options: ['Only the policyholder', 'The entire family under one sum', 'Only hospital expenses', 'Only motor claims'],
      correctIndex: 1,
      explanation: 'A floater policy covers your entire family under a single sum insured.',
    ),
    _QuizQuestion(
      question: 'What is a cashless claim?',
      options: ['You pay nothing ever', 'Insurer pays the hospital directly', 'You get cash back', 'No documents needed'],
      correctIndex: 1,
      explanation: 'In a cashless claim, your insurer settles the bill directly with the network hospital.',
    ),
    _QuizQuestion(
      question: 'No Claim Bonus (NCB) rewards you for:',
      options: ['Filing more claims', 'Not making a claim in a year', 'Paying premiums on time', 'Adding family members'],
      correctIndex: 1,
      explanation: 'NCB is a reward for not filing claims — you get a discount or increased coverage.',
    ),
    _QuizQuestion(
      question: 'A pre-existing disease is:',
      options: ['A new illness', 'A condition you had before buying the policy', 'A disease covered from day one', 'An excluded disease always'],
      correctIndex: 1,
      explanation: 'Pre-existing conditions existed before the policy and usually have a longer waiting period.',
    ),
    _QuizQuestion(
      question: 'If your sum insured is ₹5 lakh and you use it all, a restoration benefit:',
      options: ['Does nothing', 'Restores the sum for the same year', 'Only works next year', 'Doubles your premium'],
      correctIndex: 1,
      explanation: 'Restoration benefit replenishes your sum insured if it gets exhausted during the year.',
    ),
  ];

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
      _quizFinished = false;
      _currentQuizIndex = 0;
      _score = 0;
    });
  }

  void _answerQuiz(int selected) {
    final q = _quizQuestions[_currentQuizIndex];
    final correct = selected == q.correctIndex;
    setState(() {
      if (correct) _score++;
      _lastAnswerCorrect = correct;
      _showingExplanation = true;
    });
  }

  void _nextQuestion() {
    setState(() {
      _showingExplanation = false;
      if (_currentQuizIndex < _quizQuestions.length - 1) {
        _currentQuizIndex++;
      } else {
        _quizFinished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insurance Basics')),
      body: _quizStarted
          ? _quizFinished
              ? _buildQuizResult()
              : _buildQuizQuestion()
          : _buildGlossary(),
    );
  }

  Widget _buildGlossary() {
    return Column(
      children: [
        // Quiz CTA banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.quiz, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Test Your Knowledge',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${_quizQuestions.length} questions about insurance basics',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _startQuiz,
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                child: const Text('Start Quiz'),
              ),
            ],
          ),
        ),
        // Terms list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _terms.length,
            itemBuilder: (context, index) {
              final t = _terms[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Icon(t.icon, color: Colors.blue),
                  ),
                  title: Text(t.term, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(t.definition, style: const TextStyle(fontSize: 13)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuizQuestion() {
    final q = _quizQuestions[_currentQuizIndex];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Text(
                'Question ${_currentQuizIndex + 1} of ${_quizQuestions.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('Score: $_score', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuizIndex + 1) / _quizQuestions.length,
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 24),
          // Question
          Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Options
          ...List.generate(q.options.length, (i) {
            final isCorrect = i == q.correctIndex;
            final showHighlight = _showingExplanation && isCorrect;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showingExplanation ? null : () => _answerQuiz(i),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    alignment: Alignment.centerLeft,
                    backgroundColor: showHighlight ? Colors.green.withValues(alpha: 0.1) : null,
                    side: showHighlight ? const BorderSide(color: Colors.green) : null,
                  ),
                  child: Text('${String.fromCharCode(65 + i)}. ${q.options[i]}', style: const TextStyle(fontSize: 15)),
                ),
              ),
            );
          }),
          // Explanation after answering
          if (_showingExplanation) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastAnswerCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _lastAnswerCorrect ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastAnswerCorrect ? 'Correct!' : 'Not quite.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _lastAnswerCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(q.explanation, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _nextQuestion,
                child: Text(
                  _currentQuizIndex < _quizQuestions.length - 1 ? 'Next Question' : 'See Results',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizResult() {
    final pct = (_score / _quizQuestions.length * 100).round();
    final message = pct >= 80
        ? 'Excellent! You know your insurance well.'
        : pct >= 50
            ? 'Good effort! Review the terms to improve.'
            : 'Keep learning! Check the glossary for terms you missed.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct >= 80 ? Icons.emoji_events : pct >= 50 ? Icons.thumb_up : Icons.school,
              size: 64,
              color: pct >= 80 ? Colors.amber : pct >= 50 ? Colors.blue : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text('Quiz Complete!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_score / ${_quizQuestions.length} correct ($pct%)',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _quizStarted = false;
                    _quizFinished = false;
                  }),
                  child: const Text('Back to Glossary'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _startQuiz,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Term {
  final String term;
  final String definition;
  final IconData icon;
  const _Term({required this.term, required this.definition, required this.icon});
}

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

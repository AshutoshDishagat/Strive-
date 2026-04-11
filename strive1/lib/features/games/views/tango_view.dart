import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class TangoView extends StatefulWidget {
  const TangoView({super.key});

  @override
  State<TangoView> createState() => _TangoViewState();
}

class _TangoViewState extends State<TangoView> {
  final List<String> _allIcons = [
    "🍎", "🌟", "🎈", "💎", "🚀", "🎵",
    "🍕", "🐱", "🐶", "🚗", "🏀", "🍔"
  ];
  
  late List<String> _deck;
  late List<bool> _isFlipped;
  late List<bool> _isMatched;
  
  int? _firstFlippedIndex;
  bool _isProcessing = false;
  int _moves = 0;
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _startLevel(1);
  }

  void _startLevel(int level) {
    _level = level;
    int numPairs = min(level * 2, _allIcons.length);
    
    // Shuffle the available icons so the emojis used change every time
    List<String> pool = List.from(_allIcons);
    pool.shuffle();
    List<String> selectedIcons = pool.sublist(0, numPairs);
    
    _deck = [...selectedIcons, ...selectedIcons];
    _deck.shuffle();
    
    _isFlipped = List.filled(_deck.length, false);
    _isMatched = List.filled(_deck.length, false);
    _firstFlippedIndex = null;
    _isProcessing = false;
    _moves = 0;
    setState(() {});
  }

  void _onCardTap(int index) async {
    if (_isProcessing || _isFlipped[index] || _isMatched[index]) return;

    setState(() {
      _isFlipped[index] = true;
    });

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
    } else {
      _moves++;
      _isProcessing = true;
      int first = _firstFlippedIndex!;
      
      if (_deck[first] == _deck[index]) {
        // Match!
        _isMatched[first] = true;
        _isMatched[index] = true;
        _firstFlippedIndex = null;
        _isProcessing = false;
      } else {
        // No Match
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _isFlipped[first] = false;
            _isFlipped[index] = false;
            _firstFlippedIndex = null;
            _isProcessing = false;
          });
        }
      }
    }
  }

  int _getCrossAxisCount() {
    if (_deck.length <= 4) return 2;
    if (_deck.length == 12) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    bool isWon = _isMatched.every((m) => m);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Tango - Level $_level", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () => _startLevel(_level),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Moves: $_moves", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (isWon)
                    const Text("LEVEL CLEARED! 🎉", style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _deck.length,
                    itemBuilder: (context, index) {
                      bool flipped = _isFlipped[index] || _isMatched[index];
                      // Scale down icon size for large decks
                      double iconSize = _deck.length > 12 ? 28 : 40;
                      
                      return GestureDetector(
                        onTap: () => _onCardTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: flipped 
                                ? (_isMatched[index] ? AppColors.primary.withAlpha(50) : AppColors.surface)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _isMatched[index] ? AppColors.primary : AppColors.border),
                            boxShadow: flipped ? [] : [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          alignment: Alignment.center,
                          child: flipped
                              ? Text(_deck[index], style: TextStyle(fontSize: iconSize))
                              : Icon(Icons.help_outline_rounded, color: AppColors.textSecondary.withAlpha(100), size: iconSize * 0.8),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (isWon)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _startLevel(_level + 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.card,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text("NEXT LEVEL", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _startLevel(1),
                      child: Text("RESTART FROM LEVEL 1", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

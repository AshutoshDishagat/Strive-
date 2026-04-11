import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class PatchesView extends StatefulWidget {
  const PatchesView({super.key});

  @override
  State<PatchesView> createState() => _PatchesViewState();
}

class _PatchesViewState extends State<PatchesView> {
  List<int> _targetPattern = [];
  List<int> _userPattern = [];
  bool _showingPattern = false;
  bool _playing = false;
  int _level = 1;
  String _message = "Memorize the patches!";

  void _startLevel() async {
    setState(() {
      _playing = true;
      _showingPattern = true;
      _userPattern = [];
      _message = "Memorize the pattern (Level $_level)...";
      
      final r = Random();
      _targetPattern = [];
      int numPatches = min(3 + (_level ~/ 2), 8); // Gets harder
      while (_targetPattern.length < numPatches) {
        int idx = r.nextInt(9);
        if (!_targetPattern.contains(idx)) {
          _targetPattern.add(idx);
        }
      }
    });

    await Future.delayed(Duration(milliseconds: max(500, 2000 - (_level * 100))));
    if (!mounted) return;
    
    setState(() {
      _showingPattern = false;
      _message = "Tap the patches!";
    });
  }

  void _onPatchTap(int index) {
    if (!_playing || _showingPattern) return;
    if (_userPattern.contains(index)) return;

    setState(() {
      if (_targetPattern.contains(index)) {
        _userPattern.add(index);
        if (_userPattern.length == _targetPattern.length) {
          _playing = false;
          _message = "Level $_level Cleared!";
          _level++;
          Future.delayed(const Duration(seconds: 1), _startLevel);
        }
      } else {
        _playing = false;
        _message = "Wrong Patch! Game Over. Reached Level $_level.";
        _showingPattern = true; // reveal correct pattern
        _level = 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Patches", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () {
              setState(() {
                _level = 1;
                _playing = false;
                _showingPattern = false;
                _userPattern = [];
                _targetPattern = [];
                _message = "Memorize the patches!";
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _message,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    bool isTarget = _targetPattern.contains(index);
                    bool isSelected = _userPattern.contains(index);
                    
                    Color color = AppColors.surface;
                    if (_showingPattern && isTarget) {
                      color = AppColors.accent;
                    } else if (isSelected) {
                      color = AppColors.primary;
                    }

                    return GestureDetector(
                      onTap: () => _onPatchTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: (isSelected || (_showingPattern && isTarget))
                             ? [BoxShadow(color: color.withAlpha(100), blurRadius: 10)]
                             : [],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Spacer(),
            if (!_playing && !_showingPattern)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: ElevatedButton(
                  onPressed: _startLevel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.card,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Text(_level == 1 ? "START GAME" : "NEXT LEVEL", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

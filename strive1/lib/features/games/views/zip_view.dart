import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class ZipView extends StatefulWidget {
  const ZipView({super.key});

  @override
  State<ZipView> createState() => _ZipViewState();
}

class _ZipViewState extends State<ZipView> {
  int _score = 0;
  int _timeLeft = 30;
  bool _isPlaying = false;
  Timer? _timer;
  
  double _x = 0.5;
  double _y = 0.5;

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _score = 0;
      _timeLeft = 30;
      _moveTarget();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _stopGame();
      }
    });
  }

  void _stopGame() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _moveTarget() {
    final r = Random();
    setState(() {
      _x = 0.1 + r.nextDouble() * 0.8; // Safe bounds
      _y = 0.1 + r.nextDouble() * 0.8;
    });
  }

  void _onTargetTap() {
    if (!_isPlaying) return;
    setState(() {
      _score++;
      _moveTarget();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
        title: Text("Zip", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Text("Score: $_score", style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Text("00:${_timeLeft.toString().padLeft(2, '0')}", style: TextStyle(color: _timeLeft <= 5 ? Colors.redAccent : AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isPlaying
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned(
                            left: _x * (constraints.maxWidth - 60),
                            top: _y * (constraints.maxHeight - 60),
                            child: GestureDetector(
                              onTapDown: (_) => _onTargetTap(),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.purpleAccent.withAlpha(150), blurRadius: 20, spreadRadius: 5)],
                                ),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_score > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Text("Final Score: $_score\nZips Tapped!", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                        ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.card,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Text(_score == 0 ? "START ZIP" : "PLAY AGAIN", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

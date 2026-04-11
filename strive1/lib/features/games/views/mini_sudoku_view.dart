import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class MiniSudokuView extends StatefulWidget {
  const MiniSudokuView({super.key});

  @override
  State<MiniSudokuView> createState() => _MiniSudokuViewState();
}

class _MiniSudokuViewState extends State<MiniSudokuView> {
  // Puzzles
  final List<List<List<int?>>> _puzzles = [
    [
      [1, null, null, 4],
      [null, 2, 3, null],
      [null, 3, 2, null],
      [4, null, null, 1],
    ],
    [
      [null, 2, null, 4],
      [3, null, 1, null],
      [2, null, 4, null],
      [null, 3, null, 1],
    ]
  ];

  late List<List<int?>> _board;
  late List<List<bool>> _isInitial;
  int? _selRow;
  int? _selCol;
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    final random = Random();
    final puzzle = _puzzles[random.nextInt(_puzzles.length)];
    
    _board = List.generate(4, (i) => List.generate(4, (j) => puzzle[i][j]));
    _isInitial = List.generate(4, (i) => List.generate(4, (j) => puzzle[i][j] != null));
    _selRow = null;
    _selCol = null;
    _isSolved = false;
    setState(() {});
  }

  void _onCellTap(int r, int c) {
    if (_isInitial[r][c] || _isSolved) return;
    setState(() {
      _selRow = r;
      _selCol = c;
    });
  }

  void _onNumberTap(int num) {
    if (_selRow != null && _selCol != null) {
      setState(() {
        _board[_selRow!][_selCol!] = num;
        _checkWin();
      });
    }
  }

  void _onClearTap() {
    if (_selRow != null && _selCol != null) {
      setState(() {
        _board[_selRow!][_selCol!] = null;
      });
    }
  }

  void _checkWin() {
    // Check missing
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (_board[r][c] == null) return;
      }
    }

    // Check rows & cols
    for (int i = 0; i < 4; i++) {
      Set<int> rowSet = {};
      Set<int> colSet = {};
      for (int j = 0; j < 4; j++) {
        rowSet.add(_board[i][j]!);
        colSet.add(_board[j][i]!);
      }
      if (rowSet.length != 4 || colSet.length != 4) return;
    }

    // Check subgrids
    for (int br = 0; br < 2; br++) {
      for (int bc = 0; bc < 2; bc++) {
        Set<int> blockSet = {};
        for (int i = 0; i < 2; i++) {
          for (int j = 0; j < 2; j++) {
            blockSet.add(_board[br * 2 + i][bc * 2 + j]!);
          }
        }
        if (blockSet.length != 4) return;
      }
    }

    setState(() {
      _isSolved = true;
      _selRow = null;
      _selCol = null;
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
        title: Text("Mini Sudoku", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            if (_isSolved) 
               Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 48),
                    const SizedBox(height: 8),
                    Text("PUZZLE SOLVED!", style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                  ]
                ),
              ),
            // Board
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(builder: (context, constraints) {
                  final cellSize = constraints.maxWidth / 4;
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxWidth,
                    child: Stack(
                      children: [
                        // Cells
                        for (int r = 0; r < 4; r++)
                          for (int c = 0; c < 4; c++)
                            Positioned(
                              left: c * cellSize,
                              top: r * cellSize,
                              width: cellSize,
                              height: cellSize,
                              child: GestureDetector(
                                onTap: () => _onCellTap(r, c),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: (_selRow == r && _selCol == c) 
                                        ? AppColors.primary.withAlpha(50) 
                                        : AppColors.surface,
                                    border: Border(
                                      right: BorderSide(color: AppColors.border, width: (c == 1) ? 2 : 1),
                                      bottom: BorderSide(color: AppColors.border, width: (r == 1) ? 2 : 1),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _board[r][c]?.toString() ?? "",
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: _isInitial[r][c] ? FontWeight.w900 : FontWeight.w500,
                                        color: _isInitial[r][c] ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const Spacer(flex: 1),
            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 1; i <= 4; i++) _buildNumButton(i.toString(), () => _onNumberTap(i)),
                  _buildNumButton("C", _onClearTap, color: Colors.redAccent.withAlpha(50), textColor: Colors.redAccent),
                ],
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: ElevatedButton(
                onPressed: _startNewGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Text("NEW GAME", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumButton(String label, VoidCallback onTap, {Color? color, Color? textColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

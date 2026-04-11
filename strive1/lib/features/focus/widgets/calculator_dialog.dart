import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';

class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _output = "0";
  String _input = "0";
  String _equation = "";
  double _num1 = 0.0;
  String _operand = "";
  bool _isNewNumber = true;

  String formatNum(double n) {
    String s = n.toString();
    if (s.endsWith(".0")) return s.substring(0, s.length - 2);
    return s;
  }

  void buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "C") {
        _input = "0";
        _num1 = 0.0;
        _operand = "";
        _equation = "";
        _isNewNumber = true;
        _output = "0";
      } else if (buttonText == "⌫") {
        if (!_isNewNumber) {
          if (_input.length > 1) {
            _input = _input.substring(0, _input.length - 1);
          } else {
            _input = "0";
            _isNewNumber = true;
          }
          _output = _input;
        }
      } else if (buttonText == "%") {
        double val = double.tryParse(_input) ?? 0.0;
        val = val / 100;
        _input = formatNum(val);
        _output = _input;
      } else if (buttonText == '+' || buttonText == '-' || buttonText == '/' || buttonText == 'X') {
        if (_operand.isNotEmpty && !_isNewNumber) {
          _calculateResult();
          _equation = "${formatNum(_num1)} $buttonText";
        } else {
          _num1 = double.tryParse(_input) ?? 0.0;
          _equation = "${formatNum(_num1)} $buttonText";
        }
        _operand = buttonText;
        _isNewNumber = true;
      } else if (buttonText == '=') {
        if (_operand.isNotEmpty) {
          String oldNum1 = formatNum(_num1);
          String num2Str = _input;
          String oldOperand = _operand;
          
          _calculateResult();
          
          _equation = "$oldNum1 $oldOperand $num2Str =";
          _operand = "";
          _isNewNumber = true;
        }
      } else if (buttonText == '.') {
        if (_isNewNumber) {
          _input = "0.";
          _isNewNumber = false;
        } else if (!_input.contains('.')) {
          _input = '$_input.';
        }
        _output = _input;
      } else {
        // It's a digit
        if (_isNewNumber || _input == "0" || _input == "Error") {
          _input = buttonText;
          _isNewNumber = false;
        } else {
          _input = _input + buttonText;
        }
        _output = _input;
      }
    });
  }

  void _calculateResult() {
    double num2 = double.tryParse(_input) ?? 0.0;
    double result = 0.0;
    
    if (_operand == "+") result = _num1 + num2;
    if (_operand == "-") result = _num1 - num2;
    if (_operand == "X") result = _num1 * num2;
    if (_operand == "/") {
      if (num2 == 0) {
        _output = "Error";
        _input = "0";
        _isNewNumber = true;
        return;
      }
      result = _num1 / num2;
    }
    
    _output = formatNum(result);
    _input = _output;
    _num1 = result;
  }

  Widget buildButton(String buttonText, {Color? color, Color? textColor}) {
    // If empty text, return empty expanded to keep layout
    if (buttonText.isEmpty) {
      return const Expanded(child: SizedBox.shrink());
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.all(18.0), // slightly smaller padding for 5 rows
            elevation: 0,
          ),
          onPressed: () => buttonPressed(buttonText),
          child: Text(
            buttonText,
            style: TextStyle(
              fontSize: 20.0, // slightly smaller text
              fontWeight: FontWeight.bold,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background.withAlpha(200),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Display
                Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_equation.isNotEmpty)
                        Text(
                          _equation,
                          style: TextStyle(fontSize: 18.0, color: AppColors.textSecondary),
                        ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _output,
                          style: TextStyle(fontSize: 48.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                // Buttons
                Column(
                  children: [
                    Row(children: [
                      buildButton("C", color: Colors.redAccent.withAlpha(50), textColor: Colors.redAccent), 
                      buildButton("⌫", color: AppColors.surface), 
                      buildButton("%", color: AppColors.surface), 
                      buildButton("/", color: AppColors.primary, textColor: Colors.black)
                    ]),
                    Row(children: [
                      buildButton("7"), buildButton("8"), buildButton("9"), buildButton("X", color: AppColors.primary, textColor: Colors.black)
                    ]),
                    Row(children: [
                      buildButton("4"), buildButton("5"), buildButton("6"), buildButton("-", color: AppColors.primary, textColor: Colors.black)
                    ]),
                    Row(children: [
                      buildButton("1"), buildButton("2"), buildButton("3"), buildButton("+", color: AppColors.primary, textColor: Colors.black)
                    ]),
                    Row(children: [
                      buildButton("00"), buildButton("0"), buildButton("."), buildButton("=", color: AppColors.accent, textColor: Colors.black)
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text("Close Calculator", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

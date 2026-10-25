import 'package:flutter/material.dart';

class ValidatedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool? isValid;
  final String? errorText;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.isValid,
    this.errorText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    if (isValid == null) {
      borderColor = Colors.grey.shade300;
    } else if (isValid == true) {
      borderColor = Colors.green;
    } else {
      borderColor = Colors.red;
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isValid == false ? Colors.red : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            errorBorder: border,
            focusedErrorBorder: border,
            errorText: isValid == false ? errorText : null,
            errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
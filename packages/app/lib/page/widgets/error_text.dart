import 'package:flutter/material.dart';

class MyErrorText extends StatefulWidget {
  final String errorText;
  final Widget action;

  const MyErrorText({super.key, required this.errorText, required this.action});

  @override
  _MyErrorTextState createState() => _MyErrorTextState();
}

class _MyErrorTextState extends State<MyErrorText> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              widget.errorText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          widget.action
        ],
      ),
    );
  }
}

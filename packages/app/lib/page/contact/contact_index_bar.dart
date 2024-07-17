// ignore_for_file: prefer_final_fields, unused_local_variable

import 'package:flutter/material.dart';

import '../common.dart';

class IndexBar extends StatefulWidget {
  final void Function(String str)? indexBarCallBack;
  const IndexBar({super.key, this.indexBarCallBack});

  @override
  // ignore: library_private_types_in_public_api
  _IndexBarState createState() => _IndexBarState();
}

class _IndexBarState extends State<IndexBar> {
  // ignore: unused_field
  Color _backColor = const Color.fromRGBO(1, 1, 1, 0.0);
  // ignore: unused_field,
  Color _textColor = Colors.black;
  double _indicatorY = 0.0;
  bool _indicatorHidden = true;
  String _indicatorText = 'A';

  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> words = [];
    for (int i = 0; i < INDEX_WORDS.length; i++) {
      words.add(
        Expanded(
          child: Text(
            INDEX_WORDS[i],
            style: TextStyle(fontSize: 12, color: _textColor),
          ),
        ),
      );
    }
    return Positioned(
      right: 0.0,
      top: screenHeight(context) / 8,
      height: screenHeight(context) / 2,
      width: 120,
      child: Row(
        children: [
          Container(
            alignment: Alignment(0, _indicatorY),
            width: 100,
            // color: Colors.red,
            child: _indicatorHidden
                ? null
                : Stack(
                    alignment: const Alignment(-0.2, 0),
                    children: [
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                      ),
                      Text(
                        _indicatorText,
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      )
                    ],
                  ),
          ),
          GestureDetector(
            onVerticalDragDown: (DragDownDetails details) {
              int index = getIndexItem(context, details.globalPosition);
              widget.indexBarCallBack!(INDEX_WORDS[index]);
              setState(() {
                _backColor = const Color.fromRGBO(1, 1, 1, 0.5);
                _textColor = Colors.white;
                _indicatorY = 2.28 / INDEX_WORDS.length * index - 1.14;
                _indicatorText = INDEX_WORDS[index];
                _indicatorHidden = false;
              });
            },
            onVerticalDragEnd: (DragEndDetails details) {
              setState(() {
                _backColor = const Color.fromRGBO(1, 1, 1, 0.0);
                _textColor = Colors.black;
                _indicatorHidden = true;
              });
            },
            onVerticalDragUpdate: (DragUpdateDetails details) {
              int index = getIndexItem(context, details.globalPosition);
              widget.indexBarCallBack!(INDEX_WORDS[index]);
              setState(() {
                _indicatorY = 2.28 / INDEX_WORDS.length * index - 1.14;
                _indicatorText = INDEX_WORDS[index];
                _indicatorHidden = false;
              });
            },
            child: Container(
              width: 20,
              color: _backColor,
              child: Column(
                children: words,
              ),
            ),
          )
        ],
      ),
    );
  }
}

int getIndexItem(BuildContext context, Offset globalPosition) {
  RenderBox box = context.findRenderObject() as RenderBox;

  var y = box.globalToLocal(globalPosition).dy;

  var itemHeight = screenHeight(context) / 2 / INDEX_WORDS.length;
  int index = y ~/ itemHeight.clamp(0, INDEX_WORDS.length - 1);
  return index;
}

// ignore: constant_identifier_names
const INDEX_WORDS = [
  // '🔍',
  // '☆',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z'
];

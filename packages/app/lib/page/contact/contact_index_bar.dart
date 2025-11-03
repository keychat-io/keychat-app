import 'package:flutter/material.dart';
import 'package:get/get.dart';

class IndexBar extends StatefulWidget {
  const IndexBar({super.key, this.indexBarCallBack});
  final void Function(String str)? indexBarCallBack;

  @override
  _IndexBarState createState() => _IndexBarState();
}

class _IndexBarState extends State<IndexBar> {
  Color _backColor = const Color.fromRGBO(1, 1, 1, 0);
  Color _textColor = Colors.black;
  double _indicatorY = 0;
  bool _indicatorHidden = true;
  String _indicatorText = 'A';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final words = <Widget>[];
    for (var i = 0; i < INDEX_WORDS.length; i++) {
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
      right: 0,
      top: Get.width / 8,
      height: Get.height / 2,
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
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
          GestureDetector(
            onVerticalDragDown: (DragDownDetails details) {
              final index = getIndexItem(context, details.globalPosition);
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
                _backColor = const Color.fromRGBO(1, 1, 1, 0);
                _textColor = Colors.black;
                _indicatorHidden = true;
              });
            },
            onVerticalDragUpdate: (DragUpdateDetails details) {
              final index = getIndexItem(context, details.globalPosition);
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
          ),
        ],
      ),
    );
  }
}

int getIndexItem(BuildContext context, Offset globalPosition) {
  final box = context.findRenderObject()! as RenderBox;

  final y = box.globalToLocal(globalPosition).dy;

  final itemHeight = Get.height / 2 / INDEX_WORDS.length;
  final index = y ~/ itemHeight.clamp(0, INDEX_WORDS.length - 1);
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
  'Z',
];

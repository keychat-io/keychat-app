import 'package:keychat/models/browser/browser_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class BookmarkEdit extends StatefulWidget {
  const BookmarkEdit({required this.model, super.key});
  final BrowserBookmark model;

  @override
  _BookmarkEditState createState() => _BookmarkEditState();
}

class _BookmarkEditState extends State<BookmarkEdit> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.model.title);
    _urlController = TextEditingController(text: widget.model.url);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          IconButton(
            onPressed: () async {
              await BrowserBookmark.delete(widget.model.id);
              EasyLoading.showSuccess('Deleted');
              Get.back<void>();
            },
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 16,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            FilledButton(
              onPressed: () async {
                if (_titleController.text.trim().isNotEmpty) {
                  widget.model.title = _titleController.text;
                }
                if (_urlController.text.trim().isNotEmpty) {
                  widget.model.url = _urlController.text;
                }
                await BrowserBookmark.update(widget.model);
                EasyLoading.showSuccess('Saved');
                Get.back<void>();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

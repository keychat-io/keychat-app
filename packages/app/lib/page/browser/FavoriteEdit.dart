import 'package:app/models/browser/browser_favorite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class FavoriteEdit extends StatefulWidget {
  const FavoriteEdit({required this.favorite, super.key});
  final BrowserFavorite favorite;

  @override
  _FavoriteEditState createState() => _FavoriteEditState();
}

class _FavoriteEditState extends State<FavoriteEdit> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.favorite.title);
    _urlController = TextEditingController(text: widget.favorite.url);
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
                  await BrowserFavorite.delete(widget.favorite.id);
                  EasyLoading.showSuccess('Deleted');
                  Get.back<void>();
                },
                icon: const Icon(Icons.delete))
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(spacing: 16, children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'URL')),
              FilledButton(
                onPressed: () async {
                  if (_titleController.text.trim().isNotEmpty) {
                    widget.favorite.title = _titleController.text;
                  }
                  if (_urlController.text.trim().isNotEmpty) {
                    widget.favorite.url = _urlController.text;
                  }
                  await BrowserFavorite.update(widget.favorite);
                  EasyLoading.showSuccess('Saved');
                  Get.back<void>();
                },
                child: const Text('Save'),
              )
            ])));
  }
}

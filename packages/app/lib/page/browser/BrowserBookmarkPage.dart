import 'package:app/models/models.dart';
import 'package:app/page/browser/BookmarkEdit.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class BrowserBookmarkPage extends StatefulWidget {
  const BrowserBookmarkPage({super.key});

  @override
  State<BrowserBookmarkPage> createState() => _BrowserBookmarkPageState();
}

class _BrowserBookmarkPageState extends State<BrowserBookmarkPage> {
  List<BrowserBookmark> _bookmarks = [];

  bool _isEditMode = false;
  bool _isLoading = true;
  Set<String> exists = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadBookmarks();
  }

  Future _loadFavorites() async {
    List<BrowserFavorite> list = await BrowserFavorite.getAll();
    Set<String> urls = list.map((e) => e.url).toSet();
    setState(() {
      exists = urls;
    });
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookmarks = await BrowserBookmark.getAll();
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      EasyLoading.showError('Failed to load bookmarks');
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _bookmarks.removeAt(oldIndex);
      _bookmarks.insert(newIndex, item);
    });

    // Update weights in database
    await BrowserBookmark.batchUpdateWeights(_bookmarks);
    _loadBookmarks();
  }

  Future<void> _deleteBookmark(BrowserBookmark bookmark) async {
    await BrowserBookmark.delete(bookmark.id);
    EasyLoading.showSuccess('Deleted');
    _loadBookmarks();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmarks'),
        actions: [
          TextButton(
            onPressed: _toggleEditMode,
            child: Text(_isEditMode ? 'Done' : 'Edit'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : _isEditMode
                  ? ReorderableListView.builder(
                      itemCount: _bookmarks.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final bookmark = _bookmarks[index];
                        return Container(
                          key: ValueKey(bookmark.id),
                          child: ListTile(
                            leading: bookmark.favicon != null
                                ? Utils.getNeworkImageOrDefault(
                                    bookmark.favicon!,
                                    size: 32,
                                    radius: 4,
                                  )
                                : Icon(Icons.bookmark),
                            title: Text(
                              bookmark.title ?? bookmark.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              bookmark.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(CupertinoIcons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteBookmark(bookmark),
                                ),
                                Icon(Icons.drag_handle),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: _bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = _bookmarks[index];
                        return ListTile(
                          leading: bookmark.favicon != null
                              ? Utils.getNeworkImageOrDefault(
                                  bookmark.favicon!,
                                  size: 32,
                                  radius: 4,
                                )
                              : Icon(Icons.bookmark),
                          title: Text(
                            bookmark.title ?? bookmark.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            bookmark.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            final controller =
                                Get.find<MultiWebviewController>();
                            controller.launchWebview(
                              initUrl: bookmark.url,
                              defaultTitle: bookmark.title,
                            );
                            if (Get.isBottomSheetOpen ?? false) {
                              Get.back();
                            }
                          },
                          onLongPress: _toggleEditMode,
                          trailing: Wrap(children: [
                            exists.contains(bookmark.url)
                                ? IconButton(
                                    onPressed: () async {
                                      await BrowserFavorite.deleteByUrl(
                                          bookmark.url);
                                      setState(() {
                                        exists = exists..remove(bookmark.url);
                                      });

                                      EasyLoading.showSuccess(
                                          'Remved from Favorites');
                                    },
                                    icon: const Icon(Icons.check,
                                        color: Colors.green))
                                : IconButton(
                                    onPressed: () async {
                                      await BrowserFavorite.add(
                                          url: bookmark.url,
                                          title: bookmark.title,
                                          favicon: bookmark.favicon);
                                      setState(() {
                                        exists = exists..add(bookmark.url);
                                      });

                                      EasyLoading.showSuccess(
                                          'Added to Favorites');
                                    },
                                    icon: const Icon(Icons.add)),
                            IconButton(
                              icon: const Icon(Icons.more_horiz),
                              onPressed: () async {
                                await Get.to(
                                    () => BookmarkEdit(model: bookmark));
                                _loadBookmarks();
                              },
                            )
                          ]),
                        );
                      },
                    ),
    );
  }
}

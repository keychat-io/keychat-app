import 'package:app/models/models.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class QuickSection extends StatelessWidget {
  const QuickSection({super.key});

  @override
  Widget build(BuildContext context) {
    MultiWebviewController controller = Get.find<MultiWebviewController>();

    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
            borderRadius: const BorderRadius.all(Radius.circular(8))),
        padding: const EdgeInsets.all(8),
        child: ResponsiveGridList(
          listViewBuilderOptions: ListViewBuilderOptions(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
          ),
          minItemWidth: 80,
          children: controller.favorites.map((favorite) {
            return _buildQuickSectionItem(favorite, controller, context);
          }).toList(),
        ));
  }
}

Widget _buildQuickSectionItem(BrowserFavorite favorite,
    MultiWebviewController controller, BuildContext context) {
  return Center(
    child: Stack(
      children: [
        controller.quickSectionItem(
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Utils.getNeworkImageOrDefault(favorite.favicon,
                  radius: 100, size: 30),
            ),
            favorite.title?.isEmpty ?? true ? favorite.url : favorite.title!,
            favorite.url,
            onTap: () {
              controller.launchWebview(
                  content: favorite.url, defaultTitle: favorite.title);
            },
            onLongPress: () async {
              if (GetPlatform.isMobile) {
                HapticFeedback.lightImpact();
              }
              BrowserBookmark? bb =
                  await BrowserBookmark.getByUrl(favorite.url);
              String title = favorite.title == null
                  ? favorite.url
                  : '${favorite.title} - ${favorite.url}';
              showCupertinoModalPopup(
                context: Get.context!,
                builder: (BuildContext context) => CupertinoActionSheet(
                  title: Text(title),
                  actions: <CupertinoActionSheetAction>[
                    CupertinoActionSheetAction(
                      onPressed: () async {
                        await BrowserFavorite.setPin(favorite);
                        EasyLoading.showSuccess('Success');
                        controller.loadFavorite();
                        Get.back();
                      },
                      child: const Text('Move to Top'),
                    ),
                    if (bb == null)
                      CupertinoActionSheetAction(
                        child: const Text('Add to bookmark'),
                        onPressed: () async {
                          await BrowserBookmark.add(
                              url: favorite.url,
                              title: favorite.title,
                              favicon: favorite.favicon);
                          EasyLoading.showSuccess('Added');
                          controller.loadFavorite();
                          Get.back();
                        },
                      ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      onPressed: () async {
                        await BrowserFavorite.delete(favorite.id);
                        EasyLoading.showSuccess('Removed');
                        controller.loadFavorite();
                        Get.back();
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                ),
              );
            },
            context: context,
            onSecondaryTapDown: (e) async {
              if (!GetPlatform.isDesktop) {
                return;
              }
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject() as RenderBox;
              final position = RelativeRect.fromRect(
                  Rect.fromPoints(
                    e.globalPosition,
                    e.globalPosition,
                  ),
                  Offset.zero & overlay.size);

              BrowserBookmark? bb =
                  await BrowserBookmark.getByUrl(favorite.url);

              showMenu(
                context: Get.context!,
                position: position,
                items: [
                  PopupMenuItem(
                    child: const Text('Move to Top'),
                    onTap: () async {
                      await BrowserFavorite.updateWeight(favorite, 0);
                      EasyLoading.showSuccess('Success');
                      controller.loadFavorite();
                    },
                  ),
                  if (bb == null)
                    PopupMenuItem(
                      child: const Text('Add to bookmark'),
                      onTap: () async {
                        await BrowserBookmark.add(
                            url: favorite.url,
                            title: favorite.title,
                            favicon: favorite.favicon);
                        EasyLoading.showSuccess('Added');
                        controller.loadFavorite();
                      },
                    ),
                  PopupMenuItem(
                    child: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await BrowserFavorite.delete(favorite.id);
                      EasyLoading.showSuccess('Removed');
                      controller.loadFavorite();
                    },
                  ),
                ],
              );
            }),
        Obx(() => controller.isFavoriteEditMode.value
            ? Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    await BrowserFavorite.delete(favorite.id);
                    EasyLoading.showSuccess('Removed');
                    controller.loadFavorite();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              )
            : SizedBox.shrink()),
      ],
    ),
  );
}

// Custom ReorderableGridView implementation
class ReorderableGridView extends StatefulWidget {
  final int crossAxisCount;
  final List<Widget> children;
  final Function(int, int) onReorder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ReorderableGridView.count({
    super.key,
    required this.crossAxisCount,
    required this.children,
    required this.onReorder,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<ReorderableGridView> createState() => _ReorderableGridViewState();
}

class _ReorderableGridViewState extends State<ReorderableGridView> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: (widget.children.length / widget.crossAxisCount).ceil(),
      onReorder: (oldIndex, newIndex) {
        // Convert row indices to item indices
        int oldItemIndex = oldIndex * widget.crossAxisCount;
        int newItemIndex = newIndex * widget.crossAxisCount;
        widget.onReorder(oldItemIndex, newItemIndex);
      },
      itemBuilder: (context, rowIndex) {
        return Row(
          key: ValueKey(rowIndex),
          children: List.generate(widget.crossAxisCount, (colIndex) {
            int itemIndex = rowIndex * widget.crossAxisCount + colIndex;
            if (itemIndex < widget.children.length) {
              return Expanded(child: widget.children[itemIndex]);
            }
            return Expanded(child: Container());
          }),
        );
      },
    );
  }
}

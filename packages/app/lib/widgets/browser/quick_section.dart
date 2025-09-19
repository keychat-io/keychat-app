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
    final controller = Get.find<MultiWebviewController>();

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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Utils.getNeworkImageOrDefault(favorite.favicon, size: 30),
            ),
            favorite.title?.isEmpty ?? true ? favorite.url : favorite.title!,
            favorite.url,
            onTap: () {
              controller.launchWebview(
                  initUrl: favorite.url, defaultTitle: favorite.title);
            },
            onLongPress: () async {
              if (GetPlatform.isMobile) {
                HapticFeedback.lightImpact();
              }
              final bb = await BrowserBookmark.getByUrl(favorite.url);
              final title = favorite.title == null
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
                        Get.back<void>();
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
                          Get.back<void>();
                        },
                      ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      onPressed: () async {
                        await BrowserFavorite.delete(favorite.id);
                        EasyLoading.showSuccess('Removed');
                        controller.loadFavorite();
                        Get.back<void>();
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Get.back<void>();
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
              final overlay =
                  Overlay.of(context).context.findRenderObject()! as RenderBox;
              final position = RelativeRect.fromRect(
                  Rect.fromPoints(
                    e.globalPosition,
                    e.globalPosition,
                  ),
                  Offset.zero & overlay.size);

              final bb = await BrowserBookmark.getByUrl(favorite.url);

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
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink()),
      ],
    ),
  );
}

// Custom ReorderableGridView implementation
class ReorderableGridView extends StatefulWidget {
  const ReorderableGridView.count({
    required this.crossAxisCount,
    required this.children,
    required this.onReorder,
    super.key,
    this.shrinkWrap = false,
    this.physics,
  });
  final int crossAxisCount;
  final List<Widget> children;
  final Function(int, int) onReorder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

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
        final oldItemIndex = oldIndex * widget.crossAxisCount;
        final newItemIndex = newIndex * widget.crossAxisCount;
        widget.onReorder(oldItemIndex, newItemIndex);
      },
      itemBuilder: (context, rowIndex) {
        return Row(
          key: ValueKey(rowIndex),
          children: List.generate(widget.crossAxisCount, (colIndex) {
            final itemIndex = rowIndex * widget.crossAxisCount + colIndex;
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

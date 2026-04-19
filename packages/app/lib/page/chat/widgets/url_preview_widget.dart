import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/page/chat/RoomUtil.dart';

class UrlPreviewWidget extends StatelessWidget {
  const UrlPreviewWidget({
    required this.url,
    this.messageId,
    super.key,
  });

  final String url;
  final int? messageId;

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;

    final fallback = _buildFallback(isDark);
    return GestureDetector(
      onTap: () => RoomUtil.tapLink(url),
      child: AnyLinkPreview(
        link: url,
        displayDirection: UIDirection.uiDirectionHorizontal,
        cache: const Duration(days: 7),
        backgroundColor:
            isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        titleStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        bodyStyle: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
          fontSize: 13,
        ),
        // Show the URL immediately instead of any_link_preview's default
        // "Fetching data..." placeholder. If the fetch succeeds the real
        // preview replaces this; if it fails, errorWidget shows the same.
        placeholderWidget: fallback,
        errorBody: '',
        errorTitle: '',
        errorWidget: fallback,
        errorImage: '',
        borderRadius: 8,
        boxShadow: const [],
      ),
    );
  }

  Widget _buildFallback(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: 20,
            color: isDark ? Colors.white70 : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.blue,
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

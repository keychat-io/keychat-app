import 'package:app/controller/chat.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/page/components.dart' show textSmallGray;
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/contact.service.dart'; // Add this import
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchMessagesPage extends StatefulWidget {
  const SearchMessagesPage({super.key, this.roomId});
  final int? roomId;

  @override
  State<SearchMessagesPage> createState() => _SearchMessagesPageState();
}

class _SearchMessagesPageState extends State<SearchMessagesPage> {
  final TextEditingController _searchController = TextEditingController();
  RxList<Message> searchResults = <Message>[].obs;
  RxBool isLoading = false.obs;
  late Room room;
  late ChatController? chatController;
  // Add a cache for contacts to prevent repeated database lookups
  final Map<String, Contact?> _contactCache = {};

  @override
  void initState() {
    super.initState();
    final roomId = widget.roomId ?? int.parse(Get.parameters['id']!);
    chatController = RoomService.getController(roomId);
    if (chatController == null) {
      Get.back<void>();
      return;
    }
    room = chatController!.roomObs.value;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty) {
      searchResults.clear();
      return;
    }
    _performSearch(_searchController.text.trim());
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    isLoading.value = true;
    try {
      final results = await MessageService.instance
          .getMessageByContent(query, room.identityId);

      // Filter results to only messages from current room
      final filteredResults =
          results.where((message) => message.roomId == room.id).toList();

      searchResults.value = filteredResults;
    } catch (e) {
      logger.e('Search error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _onMessageTap(Message message) {
    if (chatController == null) return;

    chatController!.loadFromMessageId(message.id);
    // Navigate back to chat room
    Get.back(id: GetPlatform.isDesktop ? GetXNestKey.room : null);
    Get.back(id: GetPlatform.isDesktop ? GetXNestKey.room : null);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myAvatar = Utils.getAvatarByIdentity(room.getIdentity());
    return Scaffold(
      appBar: AppBar(title: const Text('Search History'), centerTitle: true),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(CupertinoIcons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          searchResults.clear();
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // Search results
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return const Center(
                  child: CupertinoActivityIndicator(),
                );
              }

              if (_searchController.text.trim().isEmpty) {
                return Center(
                  child:
                      textSmallGray(context, 'Enter text to search messages'),
                );
              }

              if (searchResults.isEmpty) {
                return Center(
                  child: textSmallGray(context, 'No messages found'),
                );
              }

              return ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final message = searchResults[index];
                  return _buildMessageItem(message, myAvatar);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message, Widget myAvatar) {
    // Don't show sender name for MLS groups or SendAll groups
    final shouldHideSenderName = !(room.isMLSGroup || room.isSendAllGroup);
    final showSenderName = !shouldHideSenderName && !message.isMeSend;

    // Get contact from cache or fetch from database if not cached
    final contact = _contactCache[message.idPubkey] ??
        (() {
          final c = ContactService.instance.getContactSync(message.idPubkey);
          _contactCache[message.idPubkey] = c; // Cache the result
          return c;
        })();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onMessageTap(message),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: message.isMeSend
                      ? myAvatar
                      : Utils.getRandomAvatar(
                          message.idPubkey,
                          contact: contact,
                        ),
                ),
                const SizedBox(width: 12),

                // Message content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender name (only when not in MLS/SendAll groups and not my message)
                      if (showSenderName) ...[
                        Text(
                          message.fromContact?.name ??
                              message.senderName ??
                              '${message.from.substring(0, 8)}...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Message content
                      Text(
                        message.realMessage ?? message.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Timestamp and sender indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(message.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (message.isMeSend)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

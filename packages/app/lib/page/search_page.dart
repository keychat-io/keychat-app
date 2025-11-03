// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:app/controller/home.controller.dart';
import 'package:app/models/contact.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/theme.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class SearchResult {
  // Pre-loaded room data

  SearchResult(this.type, this.data, {this.room});
  final String type; // 'contact' or 'message'
  final dynamic data; // Contact or Message
  final Room? room;
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  RxList<Contact> contactResults = <Contact>[].obs;
  RxList<Message> messageResults = <Message>[].obs;
  RxBool isLoading = false.obs;
  RxString currentQuery = ''.obs;

  // Cache for pre-loaded rooms to avoid repeated FutureBuilder calls
  final Map<String, Room> _roomCache = {};

  // Debounce timer for search optimization
  Timer? _debounceTimer;

  Identity identity = Get.find<HomeController>().getSelectedIdentity();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer for debouncing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    currentQuery.value = query.trim();

    if (query.trim().isEmpty) {
      contactResults.clear();
      messageResults.clear();
      return;
    }

    isLoading.value = true;

    try {
      // Search contacts and messages in parallel
      final futures = await Future.wait([
        _searchContacts(query.trim()),
        _searchMessages(query.trim()),
      ]);

      contactResults.value = futures[0] as List<Contact>;
      messageResults.value = futures[1] as List<Message>;

      // Pre-load rooms for contacts to avoid FutureBuilder
      await _preloadContactRooms(contactResults);
      await _preloadMessageRooms(messageResults);
    } catch (e) {
      // Handle error
      contactResults.clear();
      messageResults.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Contact>> _searchContacts(String query) async {
    return ContactService.instance.getContactListSearch(query, identity.id);
  }

  Future<List<Message>> _searchMessages(String query) async {
    return MessageService.instance.getMessageByContent(query, identity.id);
  }

  Future<void> _preloadContactRooms(List<Contact> contacts) async {
    for (final contact in contacts) {
      final cacheKey = 'contact_${contact.pubkey}';
      if (!_roomCache.containsKey(cacheKey)) {
        try {
          final room = await RoomService.instance.getOrCreateRoom(
            contact.pubkey,
            identity.secp256k1PKHex,
            RoomStatus.enabled,
          );
          room.contact = contact;
          _roomCache[cacheKey] = room;
        } catch (e) {
          // Handle error
        }
      }
    }
  }

  Future<void> _preloadMessageRooms(List<Message> messages) async {
    for (final message in messages) {
      final cacheKey = 'message_${message.roomId}';
      if (!_roomCache.containsKey(cacheKey)) {
        try {
          final room =
              await RoomService.instance.getRoomByIdOrFail(message.roomId);
          final contact = await ContactService.instance.getContact(
            message.identityId,
            message.idPubkey,
          );
          room.contact = contact;
          _roomCache[cacheKey] = room;
        } catch (e) {
          // Handle error
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        title: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Icon(Icons.search),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search contacts and messages...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          contactResults.clear();
                          messageResults.clear();
                          currentQuery.value = '';
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: Get.back,
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: MaterialTheme.lightScheme().primary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    return Obx(() {
      if (isLoading.value) {
        return const Center(
          child: CupertinoActivityIndicator(),
        );
      }

      if (currentQuery.value.isEmpty) {
        return const Center(
          child: Text(
            'Enter text to search contacts and messages',
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      if (contactResults.isEmpty && messageResults.isEmpty) {
        return const Center(
          child: Text(
            'No results found',
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      return CustomScrollView(
        slivers: [
          // Contacts section
          if (contactResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Contacts (${contactResults.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildContactItem(contactResults[index]),
                childCount: contactResults.length,
              ),
            ),
          ],

          // Messages section
          if (messageResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Chat History (${messageResults.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMessageItem(messageResults[index]),
                childCount: messageResults.length,
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildContactItem(Contact contact) {
    final cacheKey = 'contact_${contact.pubkey}';
    final room = _roomCache[cacheKey];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (room != null) {
              await Utils.offAndToNamedRoom(room);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Utils.getRandomAvatar(
                    contact.pubkey,
                    contact: contact,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${contact.npubkey.substring(0, 18)}...${contact.npubkey.substring(contact.npubkey.length - 18)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    final cacheKey = 'message_${message.roomId}';
    final room = _roomCache[cacheKey];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          onTap: () async {
            if (room != null) {
              await Utils.offAndToNamedRoom(room, {
                'room': room,
                'messageId': message.id,
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room != null)
                  Utils.getAvatarByRoom(room)
                else
                  Utils.getRandomAvatar(message.idPubkey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.isMeSend
                                  ? identity.displayName
                                  : room?.getRoomName() ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            Utils.formatTimeForMessage(message.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.realMessage ?? message.content,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

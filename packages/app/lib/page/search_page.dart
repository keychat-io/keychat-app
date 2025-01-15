// ignore_for_file: library_private_types_in_public_api

import 'package:app/controller/home.controller.dart';
import 'package:app/models/contact.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/message.dart';
import 'package:app/page/theme.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/room.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class SearchResult {
  final String type; // contact/message
  final dynamic data;

  SearchResult(this.type, this.data);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Message> _searchMessageResults = [];
  List<Contact> _searchContactResults = [];
  final List<SearchResult> _searchResults = [];
  Identity identity = Get.find<HomeController>().getSelectedIdentity();

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
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    children: [
                      const Icon(Icons.search),
                      const SizedBox(width: 2.0),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (query) async {
                            List<Message> messages =
                                await _mockSearchMessage(identity, query);
                            setState(() {
                              _searchMessageResults = messages;
                              _searchContactResults = _mockSearchContact(query);

                              if (_searchResults.isNotEmpty) {
                                _searchResults.clear();
                              }

                              _searchResults.add(SearchResult("first", []));
                              _searchResults.addAll(_searchContactResults.map(
                                  (contact) =>
                                      SearchResult("contact", contact)));
                              _searchResults.add(SearchResult("second", []));
                              _searchResults.addAll(_searchMessageResults.map(
                                  (message) =>
                                      SearchResult("message", message)));
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search',
                            border: InputBorder.none,
                            hintStyle: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchMessageResults.clear();
                            _searchContactResults.clear();
                            _searchResults.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5.0),
              GestureDetector(
                onTap: () {
                  Get.back();
                },
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: 16.0,
                        color: MaterialTheme.lightScheme().primary)),
              ),
            ],
          )),
      body: _buildSerachResults(),
    );
  }

  Widget _buildSerachResults() {
    return ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          SearchResult result = _searchResults[index];
          if (result.type == "first") {
            if (_searchContactResults.isEmpty) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Contacts"),
                  SizedBox(
                    height: 5,
                  ),
                  Text("  No contact found."),
                  SizedBox(
                    height: 5,
                  ),
                ],
              );
            }
            return const Text("Contacts");
          }
          if (result.type == "second") {
            if (_searchMessageResults.isEmpty) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Chat History"),
                  SizedBox(
                    height: 5,
                  ),
                  Text("  No chat history found."),
                  SizedBox(
                    height: 5,
                  ),
                ],
              );
            }
            return const Text("Chat History");
          }
          if (result.type == 'contact') {
            return FutureBuilder(future: () async {
              Room room = await RoomService.instance.getOrCreateRoom(
                  _searchResults[index].data.pubkey,
                  identity.secp256k1PKHex,
                  RoomStatus.enabled);

              room.contact = _searchResults[index].data;
              return room;
            }(), builder: (context, snapshot) {
              return ListTile(
                onTap: () async {
                  Room? room = snapshot.data;
                  if (room == null) return;
                  await Get.offAndToNamed('/room/${room.id}', arguments: room);
                },
                // leading: const Text("Contact:"),
                leading: Utils.getRandomAvatar(
                    _searchResults[index].data.pubkey,
                    height: 40,
                    width: 40),
                title: Text(
                  _searchResults[index].data.displayName.toString(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  "${_searchResults[index].data.npubkey.substring(0, 18)}...${_searchResults[index].data.npubkey.substring(_searchResults[index].data.npubkey.length - 18)}",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                dense: true,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.black12, width: 0.1),
                  borderRadius: BorderRadius.circular(0),
                ),
              );
            });
          } else {
            return FutureBuilder(future: () async {
              Room room = await RoomService.instance
                  .getRoomByIdOrFail(_searchResults[index].data.roomId);
              Contact? contact = await ContactService.instance.getContact(
                  _searchResults[index].data.identityId,
                  _searchResults[index].data.idPubkey);
              room.contact = contact;
              return room;
            }(), builder: (context, snapshot) {
              return ListTile(
                onTap: () async {
                  Room? room = snapshot.data;
                  if (room == null) return;
                  await Get.toNamed('/room/${room.id}', arguments: {
                    "room": room,
                    "searchDt": _searchResults[index].data.createdAt,
                    "isFromSearch": true
                  });
                },
                // leading: const Text("Message:"),
                leading: Utils.getRandomAvatar(
                    _searchResults[index].data.idPubkey,
                    height: 40,
                    width: 40),
                title: Text(
                  _searchResults[index].data.isMeSend
                      ? identity.displayName
                      : snapshot.data?.getRoomName() ?? "Room",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  _searchResults[index].data.realMessage ??
                      _searchResults[index].data.content,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: Text(Utils.getFormatTimeForMessage(
                    _searchResults[index].data.createdAt)),
                dense: true,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.black12, width: 0.1),
                  borderRadius: BorderRadius.circular(0),
                ),
              );
            });
          }
        });
  }

  Future<List<Message>> _mockSearchMessage(
      Identity identity, String query) async {
    if (query.isEmpty) {
      return [];
    }
    return await MessageService.instance
        .getMessageByContent(query, identity.id);
  }

  List<Contact> _mockSearchContact(String query) {
    if (query.isEmpty) {
      return [];
    } else {
      List<Contact> list =
          ContactService.instance.getContactListSearch(query, identity.id);
      return list;
    }
  }
}

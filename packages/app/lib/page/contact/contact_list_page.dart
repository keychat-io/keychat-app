// ignore_for_file: must_be_immutable

import 'package:app/models/models.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/page/contact/ContactDetail/ContactDetail_page.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../components.dart';
import 'contact_index_bar.dart';

class ContactsPage extends StatefulWidget {
  final Identity identity;
  const ContactsPage(this.identity, {super.key});
  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final List<Contact> _headerData = [];
  List<Contact> _listDatas = [];
  final ScrollController _scrollController = ScrollController();

  final double _cellHeight = 54.0;
  final double _groupHeight = 30.0;
  final Map _groupOffsetMap = {
    INDEX_WORDS[0]: 0.0,
    INDEX_WORDS[0]: 0.0,
  };

  _getData() async {
    List<Contact> contactList =
        await ContactService.instance.getContactList(widget.identity.id);

    List<Contact> contactStartNum = [];
    List<Contact> restContacts = [];
    for (var element in contactList) {
      if (element.displayName.toString().startsWith(RegExp(r'[0-9]'))) {
        contactStartNum.add(element);
      } else {
        restContacts.add(element);
      }
    }
    // contactList.sort(((a, b) => a.displayName.compareTo(b.displayName)));
    restContacts.sort(((a, b) => a.displayName.compareTo(b.displayName)));
    contactStartNum.sort(((a, b) => a.displayName.compareTo(b.displayName)));
    restContacts.addAll(contactStartNum);

    setState(() {
      _listDatas = restContacts;
    });
  }

  @override
  void initState() {
    super.initState();

    _getData();

    Future.delayed(Duration.zero, () {
      var groupOffset = _cellHeight * _headerData.length;
      for (int i = 0; i < _listDatas.length; i++) {
        if (i < 1) {
          _groupOffsetMap.addAll({_listDatas[i].indexLetter: groupOffset});
          groupOffset += _cellHeight + _groupHeight;
        } else if (_listDatas[i].indexLetter == _listDatas[i - 1].indexLetter) {
          groupOffset += _cellHeight;
        } else {
          _groupOffsetMap.addAll({_listDatas[i].indexLetter: groupOffset});
          groupOffset += _cellHeight + _groupHeight;
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
                onPressed: () {
                  Get.bottomSheet(
                      clipBehavior: Clip.antiAlias,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(4))),
                      const AddtoContactsPage(""),
                      isScrollControlled: true,
                      ignoreSafeArea: false);
                },
                icon: const Icon(CupertinoIcons.person_add)),
            IconButton(
                onPressed: () {
                  showSearchContactsPage(context, _listDatas);
                },
                icon: const Icon(CupertinoIcons.search)),
            IconButton(
                onPressed: () {
                  copyAllContacts(_listDatas);
                },
                icon: const Icon(CupertinoIcons.down_arrow)),
          ],
          centerTitle: true,
          title: const Text(
            'Contacts',
          ),
        ),
        body: ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: _headerData.length + _listDatas.length,
          controller: _scrollController,
          itemBuilder: (BuildContext context, int index) {
            if (index < _headerData.length) {
              return _FriendCell(
                  contact: _headerData[index],
                  imageAssets: _headerData[index].imageAssets,
                  updateList: _getData);
            } else {
              String? groupTitle = _listDatas[index].indexLetter;

              if (index - _headerData.length > 0) {
                bool isShowT =
                    _listDatas[index - _headerData.length].indexLetter ==
                        _listDatas[index - _headerData.length - 1].indexLetter;

                if (isShowT) {
                  groupTitle = null;
                }
              }
              return _FriendCell(
                  contact: _listDatas[index - _headerData.length],
                  groupTitle: groupTitle,
                  updateList: _getData);
            }
          },
        ));
  }
}

class _FriendCell extends StatelessWidget {
  final Contact contact;
  final String? groupTitle;
  final String? imageAssets;
  final VoidCallback updateList;

  const _FriendCell(
      {required this.contact,
      required this.updateList,
      this.groupTitle,
      this.imageAssets});
  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(contact.id),
      children: [
        Container(
          color: Get.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade300,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          height: groupTitle != null ? 20 : 0,
          child: groupTitle != null
              ? Text(
                  groupTitle!,
                  style: const TextStyle(color: Colors.grey),
                )
              : null,
        ),
        InkWell(
          onTap: () async {
            await Get.bottomSheet(
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(4))),
                ContactDetailPage(contact),
                isScrollControlled: true,
                ignoreSafeArea: false);
            updateList();
          },
          child: ListTile(
              leading: Utils.getRandomAvatar(contact.pubkey,
                  httpAvatar: contact.avatarFromRelay, height: 36, width: 36),
              title: Text(contact.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18)),
              subtitle: textSmallGray(
                  context, getPublicKeyDisplay(contact.npubkey, 14))),
        ),
        Container(
            height: 0.4,
            color:
                Get.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade300),
      ],
    );
  }
}

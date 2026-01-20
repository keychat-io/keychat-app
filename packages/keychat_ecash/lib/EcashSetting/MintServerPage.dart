import 'dart:async';

import 'package:keychat/global.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:settings_ui/settings_ui.dart';

class MintInfo {
  MintInfo({
    this.name,
    this.pubkey,
    this.version,
    this.description,
    this.descriptionLong,
    this.contact,
    this.motd,
    this.iconUrl,
    this.time,
    this.nuts,
  });

  factory MintInfo.fromJson(Map<String, dynamic> json) {
    List<MintContactInfo>? contactList;
    if (json['contact'] != null) {
      contactList = (json['contact'] as List)
          .map((item) => MintContactInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return MintInfo(
      name: json['name'] as String?,
      pubkey: json['pubkey'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      descriptionLong: json['description_long'] as String?,
      contact: contactList,
      motd: json['motd'] as String?,
      iconUrl: json['icon_url'] as String?,
      time: json['time'] as int?,
      nuts: json['nuts'] as Map<String, dynamic>?,
    );
  }
  final String? name;
  final String? pubkey;
  final String? version;
  final String? description;
  final String? descriptionLong;
  final List<MintContactInfo>? contact;
  final String? motd;
  final String? iconUrl;
  final int? time;
  final Map<String, dynamic>? nuts;
}

class MintContactInfo {
  MintContactInfo({required this.method, required this.info});

  factory MintContactInfo.fromJson(Map<String, dynamic> json) {
    return MintContactInfo(
      method: json['method'] as String,
      info: json['info'] as String,
    );
  }
  final String method;
  final String info;
}

class MintServerPage extends StatefulWidget {
  const MintServerPage(this.server, {super.key});
  final MintBalanceClass server;

  @override
  _MintServerPageState createState() => _MintServerPageState();
}

class _MintServerPageState extends State<MintServerPage> {
  MintInfo? mintInfo;
  bool isLoading = true;
  String? errorMessage;
  Set<String> currency = {};

  @override
  void initState() {
    super.initState();
    unawaited(_fetchMintInfo());
  }

  Future<void> _fetchMintInfo() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      var url = '${widget.server.mint}/v1/info';
      if (widget.server.mint.endsWith('/')) {
        url = '${widget.server.mint}v1/info';
      }

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        logger.d('Mint info: $data');
        MintInfo? info;
        try {
          info = MintInfo.fromJson(data as Map<String, dynamic>);
          if (info.nuts != null) {
            info.nuts!.forEach((key, value) {
              if (key == '4') {
                if (value['disabled'] == false) {
                  for (final item in (value['methods'] as Iterable)) {
                    if (item['unit'] != null && item['description'] == true) {
                      currency.add(item['unit'] as String);
                    }
                  }
                }
              }
            });
          }
          // ignore: empty_catches
        } catch (e) {}
        setState(() {
          mintInfo = info;
          isLoading = false;
          currency = currency;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load mint info: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      logger.e('Error fetching mint info: $e');
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mintInfo?.name ?? widget.server.mint)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (mintInfo != null &&
                    mintInfo?.motd != null &&
                    mintInfo!.motd != 'Message to users')
                  NoticeTextWidget.warning(mintInfo?.motd ?? ''),
                Expanded(
                  child: SettingsList(
                    platform: DevicePlatform.iOS,
                    sections: [
                      SettingsSection(
                        tiles: [
                          SettingsTile(
                            title: Text(widget.server.mint),
                            trailing: const Icon(Icons.copy),
                            description: mintInfo != null &&
                                    mintInfo?.description != null
                                ? Text(mintInfo!.description!)
                                : null,
                            onPressed: (_) {
                              Clipboard.setData(
                                ClipboardData(text: widget.server.mint),
                              );
                              EasyLoading.showToast('Copied');
                            },
                          ),
                        ],
                      ),

                      // Basic info section
                      if (mintInfo != null)
                        SettingsSection(
                          title: const Text('Mint Information'),
                          tiles: [
                            if (mintInfo?.name != null)
                              SettingsTile(
                                title: const Text('Name'),
                                value: Text(mintInfo!.name!),
                              ),
                            if (mintInfo?.version != null)
                              SettingsTile(
                                title: const Text('Version'),
                                value: Text(mintInfo!.version!),
                              ),
                            if (currency.isNotEmpty)
                              SettingsTile(
                                title: const Text('Currencies'),
                                value: Text(currency.join(', ')),
                              ),
                            if (mintInfo?.pubkey != null)
                              SettingsTile(
                                title: const Text('Public Key'),
                                value: mintInfo!.pubkey != null
                                    ? Flexible(child: Text(mintInfo!.pubkey!))
                                    : null,
                                onPressed: (_) {
                                  Clipboard.setData(
                                    ClipboardData(text: mintInfo!.pubkey!),
                                  );
                                  EasyLoading.showToast('Public key copied');
                                },
                              ),
                            if (mintInfo?.descriptionLong != null)
                              SettingsTile(
                                title: const Text('Detailed Description'),
                                description: Text(mintInfo!.descriptionLong!),
                              ),
                          ],
                        ),

                      // Contact section
                      if (mintInfo?.contact != null &&
                          mintInfo!.contact!.isNotEmpty)
                        SettingsSection(
                          title: const Text('Contact'),
                          tiles: mintInfo!.contact!
                              .map(
                                (contact) => SettingsTile(
                                  title: Text(contact.method.capitalizeFirst!),
                                  value: Flexible(child: Text(contact.info)),
                                  onPressed: (_) {
                                    Clipboard.setData(
                                      ClipboardData(text: contact.info),
                                    );
                                    EasyLoading.showToast('Copied');
                                  },
                                ),
                              )
                              .toList(),
                        ),

                      // NUTS section
                      if (mintInfo?.nuts != null && mintInfo!.nuts!.isNotEmpty)
                        _buildNutsSection(),

                      deleteSection(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  SettingsSection _buildNutsSection() {
    final nutTiles = <SettingsTile>[];

    mintInfo!.nuts!.forEach((nutNumber, nutData) {
      final nutTitle = 'NUT-$nutNumber';
      final nutDescription = _formatNutData(nutData, nutNumber);

      nutTiles.add(
        SettingsTile(
          title: Text(nutTitle),
          value: Text(nutDescription),
          onPressed: (_) {
            // Show detailed nut information in dialog
            Get.dialog(
              CupertinoAlertDialog(
                title: Text(nutTitle),
                content: SingleChildScrollView(
                  child: Text(
                    _formatNutDataDetailed(nutData, nutNumber),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });

    return SettingsSection(
      title: const Text('Supported NUTS'),
      tiles: nutTiles,
    );
  }

  String _formatNutData(dynamic nutData, String nutNumber) {
    if (nutData is Map) {
      if (nutData.containsKey('supported')) {
        if (nutData['supported'] == true) {
          return 'Supported';
        } else if (nutData['supported'] is List) {
          return "Supported with ${(nutData['supported'] as List).length} methods";
        }
      } else if (nutData.containsKey('methods')) {
        return "Supports ${(nutData['methods'] as List).length} payment methods";
      } else if (nutData.containsKey('cached_endpoints')) {
        return "Caching supported with ${(nutData['cached_endpoints'] as List).length} endpoints";
      } else if (nutData.containsKey('disabled') &&
          nutData['disabled'] == true) {
        return 'Disabled';
      }
    }
    return 'Available';
  }

  String _formatNutDataDetailed(dynamic nutData, String nutNumber) {
    if (nutData is! Map) {
      return 'No detailed information available';
    }

    final buffer = StringBuffer();

    // Handle supported boolean
    if (nutData.containsKey('supported') && nutData['supported'] == true) {
      buffer.writeln('• Supported: Yes');
    }

    // Handle disabled flag
    if (nutData.containsKey('disabled')) {
      buffer.writeln("• Disabled: ${nutData['disabled']}");
    }

    // Handle methods
    if (nutData.containsKey('methods') && nutData['methods'] is Iterable) {
      buffer.writeln('\nMethods:');
      for (final method in nutData['methods'] as Iterable) {
        if (method is Map) {
          buffer.writeln("\n  Method: ${method['method']}");
          method.forEach((key, value) {
            if (key != 'method') {
              buffer.writeln('  • $key: $value');
            }
          });
        }
      }
    }

    // Handle supported list
    if (nutData.containsKey('supported') && nutData['supported'] is List) {
      buffer.writeln('\nSupported methods:');
      final supportedList = nutData['supported'] as List;
      for (final item in supportedList) {
        if (item is Map) {
          buffer.writeln("\n  Method: ${item['method']}");
          item.forEach((key, value) {
            if (key != 'method') {
              if (value is List) {
                buffer.writeln("  • $key: ${value.join(", ")}");
              } else {
                buffer.writeln('  • $key: $value');
              }
            }
          });
        }
      }
    }

    // Handle cached endpoints
    if (nutData.containsKey('cached_endpoints') &&
        nutData['cached_endpoints'] is Iterable) {
      buffer.writeln('\nCached endpoints:');
      for (final endpoint in nutData['cached_endpoints'] as Iterable) {
        if (endpoint is Map) {
          buffer.writeln("  • ${endpoint['method']} ${endpoint['path']}");
        }
      }

      if (nutData.containsKey('ttl')) {
        buffer.writeln("\nTTL: ${nutData['ttl']} seconds");
      }
    }

    return buffer.toString();
  }

  SettingsSection deleteSection() {
    return SettingsSection(
      tiles: [
        SettingsTile(
          title: const Text('Delete Mint', style: TextStyle(color: Colors.red)),
          onPressed: (context) async {
            try {
              final ec = Get.find<EcashController>();
              if (ec.mintBalances.length == 1) {
                EasyLoading.showError("Can't delete the last mint");
                return;
              }
              EasyLoading.show(status: 'Processing');

              final balance = ec.getBalanceByMint(widget.server.mint);
              if (balance > 0) {
                EasyLoading.showError('Please withdraw first');
                return;
              }
              if (balance == 0) {
                await rust_cashu.removeMint(url: widget.server.mint);
              }
              await ec.getBalance();
              EasyLoading.showToast('Successfully');
              Get.back(id: GetPlatform.isDesktop ? GetXNestKey.ecash : null);
            } catch (e, s) {
              EasyLoading.dismiss();
              final msg = Utils.getErrorMessage(e);

              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(msg);
            }
          },
        ),
      ],
    );
  }
}

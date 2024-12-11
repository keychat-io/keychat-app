// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_invitation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupInvitationModel _$GroupInvitationModelFromJson(
        Map<String, dynamic> json) =>
    GroupInvitationModel(
      name: json['name'] as String,
      pubkey: json['pubkey'] as String,
      sender: json['sender'] as String,
      time: (json['time'] as num).toInt(),
      sig: json['sig'] as String,
    );

Map<String, dynamic> _$GroupInvitationModelToJson(
        GroupInvitationModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'pubkey': instance.pubkey,
      'sender': instance.sender,
      'time': instance.time,
      'sig': instance.sig,
    };

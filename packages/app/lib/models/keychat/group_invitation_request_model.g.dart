// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_invitation_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupInvitationRequestModel _$GroupInvitationRequestModelFromJson(
        Map<String, dynamic> json) =>
    GroupInvitationRequestModel(
      name: json['name'] as String,
      roomPubkey: json['roomPubkey'] as String,
      myPubkey: json['myPubkey'] as String,
      myName: json['myName'] as String,
      mlsPK: json['mlsPK'] as String,
      time: (json['time'] as num).toInt(),
      sig: json['sig'] as String,
    );

Map<String, dynamic> _$GroupInvitationRequestModelToJson(
        GroupInvitationRequestModel instance) =>
    <String, dynamic>{
      'roomPubkey': instance.roomPubkey,
      'name': instance.name,
      'myPubkey': instance.myPubkey,
      'myName': instance.myName,
      'time': instance.time,
      'mlsPK': instance.mlsPK,
      'sig': instance.sig,
    };

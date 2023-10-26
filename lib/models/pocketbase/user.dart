// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';

class User {
  String id;
  String collectionId;
  String collectionName;
  String username;
  bool verified;
  bool emailVisibility;
  String email;
  String created;
  String updated;
  List<String> sharing;
  bool terabyte_active;
  bool prereg_bonus;
  String glassfy;
  int capacity_gigs;
  bool usingPersonalEncryption;
  String personalEncryptionHashes;

  User({
    this.id = "",
    this.collectionId = "",
    this.collectionName = "",
    this.username = "",
    this.verified = false,
    this.emailVisibility = false,
    this.email = "",
    this.created = "",
    this.updated = "",
    this.sharing = const [],
    this.terabyte_active = false,
    this.glassfy = "",
    this.capacity_gigs = 5,
    this.usingPersonalEncryption = false,
    this.personalEncryptionHashes = "",
    this.prereg_bonus = false,
  });

  // delete user
  Future<bool> deleteUser() async {
    await pb.collection('users').delete(id);
    return true;
  }

  // get single user
  Future<User> getUser(String id) async {
    final result = await pb.collection('users').getOne(id);
    logger.i("Get user: ${jsonEncode(result)}");

    return User(
      id: result.id,
      collectionId: result.getStringValue('collectionId'),
      collectionName: result.getStringValue('collectionName'),
      username: result.getStringValue('username'),
      verified: result.getBoolValue('verified'),
      emailVisibility: result.getBoolValue('emailVisibility'),
      email: result.getStringValue('email'),
      created: result.getStringValue('created'),
      updated: result.getStringValue('updated'),
      sharing: result.getListValue('sharing'),
      terabyte_active: result.getBoolValue('terabyte_active'),
      prereg_bonus: result.getBoolValue('prereg_bonus'),
      glassfy: result.getStringValue('glassfy'),
      capacity_gigs: result.getIntValue('capacity_gigs'),
      usingPersonalEncryption: result.getBoolValue('usingPersonalEncryption'),
      personalEncryptionHashes:
          result.getStringValue('personalEncryptionHashes'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collectionId': collectionId,
        'collectionName': collectionName,
        'username': username,
        'verified': verified,
        'emailVisibility': emailVisibility,
        'email': email,
        'created': created,
        'updated': updated,
        'sharing': sharing,
        'terabyte_active': terabyte_active,
        'prereg_bonus': prereg_bonus,
        'glassfy': glassfy,
        'capacity_gigs': capacity_gigs,
        'usingPersonalEncryption': usingPersonalEncryption,
        'personalEncryptionHashes': personalEncryptionHashes,
      };
}

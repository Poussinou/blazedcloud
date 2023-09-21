import 'dart:convert';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:pocketbase/pocketbase.dart';

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
  });

  // We are manually parsing the json for now to get the friends
  // using this for loading friend request only for now
  factory User.fromJson(dynamic json, RecordModel record) {
    logger.i("User from json: ${jsonEncode(json)}");
    return User(
      id: json['id'],
      username: json['username'],
      sharing: json['sharing'],
    );
  }

  // delete user
  Future<bool> deleteUser() async {
    await pb.collection('users').delete(id);
    return true;
  }

  // get single user
  Future<User> getUser(String id) async {
    final result = await pb.collection('users').getOne(id, expand: 'friends');
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
      };
}

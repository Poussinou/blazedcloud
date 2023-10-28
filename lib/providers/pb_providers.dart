import 'package:blazedcloud/models/pocketbase/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final accountUserProvider =
    FutureProvider.family<User, String>((ref, id) async {
  return ref.read(userProvider).getUser(id);
});

final userProvider = Provider<User>((ref) => User());

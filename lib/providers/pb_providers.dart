import 'package:blazedcloud/models/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final accountUserProvider =
    FutureProvider.family<User, String>((ref, id) async {
  return ref.read(userProvider).getUser(id);
});

final premiumProvider = StateProvider<bool>((ref) => false);

final userProvider = Provider<User>((ref) => User());

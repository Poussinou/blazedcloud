import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/models/files_api/list_files.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentDirectoryProvider =
    StateProvider<String>((ref) => pb.authStore.model.id + '/');

/// pass the directory to list files from. Use empty string for root
final fileListProvider =
    FutureProvider.family<ListBucketResult, String>((ref, from) async {
  return getFilelist(pb.authStore.model.id, from, pb.authStore.token);
});

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void delete(String folderKey, BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete folder'),
      content: const Text('Are you sure you want to delete this Folder?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Handle delete action here
            logger.i('Deleting $folderKey');
            Navigator.of(context).pop();
            deleteFolder(pb.authStore.model.id, folderKey, pb.authStore.token)
                .then((_) =>
                    ref.invalidate(fileListProvider(pb.authStore.model.id)));
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class FolderItem extends ConsumerWidget {
  final String folderKey;

  const FolderItem({
    super.key,
    required this.folderKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.folder),
          title: Text(getFolderName(folderKey)),
          trailing: PopupMenuButton<String>(
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'save',
                child: Text('Save'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
            onSelected: (value) {
              if (value == 'save') {
                logger.e("Not implemented yet");
              } else if (value == 'delete') {
                delete(folderKey, context, ref);
              }
            },
          ),
        ),
      ),
      onTapDown: (details) {
        // change the current directory to the folder name
        ref.read(currentDirectoryProvider.notifier).state =
            '${ref.read(currentDirectoryProvider.notifier).state}${getFolderName(folderKey)}/';
      },
    );
  }
}

import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                value: 'open',
                child: Text('Open'),
              ),
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
              if (value == 'open') {
                logger.e("Not implemented yet");
              } else if (value == 'save') {
                logger.e("Not implemented yet");
              } else if (value == 'delete') {
                logger.e("Not implemented yet");
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

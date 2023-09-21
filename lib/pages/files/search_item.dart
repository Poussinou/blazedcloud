import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/pages/files/file_item.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchItem extends ConsumerWidget {
  final String fileKey;

  const SearchItem({
    super.key,
    required this.fileKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FileType type = getFileType(fileKey);
    final downloadController = ref.watch(downloadControllerProvider);

    return InkWell(
      child: Card(
        child: ListTile(
          leading: Icon(
            type == FileType.image
                ? Icons.image
                : type == FileType.video
                    ? Icons.video_library
                    : Icons.insert_drive_file,
          ),
          title: Text(getFileName(fileKey)),
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
                saveItem(fileKey, ref);
              } else if (value == 'save') {
                downloadItem(fileKey, downloadController);
              } else if (value == 'delete') {
                // ask for confirmation before deleting
                deleteItem(fileKey, context, ref);
              }
            },
          ),
        ),
      ),
      onTap: () {
        Navigator.of(context).pop(fileKey);

        logger.i('Going to $fileKey');

        // change current directory to the directory of the file
        ref.read(currentDirectoryProvider.notifier).state =
            getFileDirectory(fileKey);
      },
    );
  }
}

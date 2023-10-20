import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/files_api/search_delagate.dart';
import 'package:blazedcloud/pages/files/file_item.dart';
import 'package:blazedcloud/pages/files/folder_item.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final newFolderNameProvider = StateProvider<String>((ref) => "");

class FilesPage extends ConsumerWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileList = ref.watch(fileListProvider(""));
    final uploadController = ref.watch(uploadControllerProvider);
    final currentDirectory = ref.watch(currentDirectoryProvider);

    return Scaffold(
      appBar: AppBar(
          title: ref.watch(currentDirectoryProvider) != getStartingDirectory()
              ? Text(ref.watch(currentDirectoryProvider))
              : const Text('Blazed Explorer'),

          // if current directory isn't root, show a back button
          leading: ref.watch(currentDirectoryProvider) != getStartingDirectory()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref.read(currentDirectoryProvider.notifier).state =
                        getParentDirectory(ref.read(currentDirectoryProvider));
                  },
                )
              : null,
          actions: [
            fileList.when(
              data: (data) => IconButton(
                onPressed: () {
                  showSearch(
                      context: context, delegate: FileSearchDelegate(data));
                },
                icon: const Icon(Icons.search),
              ),
              loading: () => const SizedBox.shrink(),
              error: (err, stack) {
                logger.e("Error loading file list: $err");
                return const SizedBox.shrink();
              },
            )
          ]),
      body: fileList.when(
        data: (data) {
          final folderList = getFolderList(data);
          return Stack(children: [
            RefreshIndicator(
              onRefresh: () async {
                // Invalidate by refreshing the FutureProvider
                ref.invalidate(fileListProvider(""));

                // Wait for the new data to load
                await ref.read(fileListProvider("").future);
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: folderList.length + (data.contents?.length ?? 0),
                itemBuilder: (context, index) {
                  if (index < folderList.length) {
                    // Render folder items
                    String folderKey = folderList[index];

                    if ("$folderKey/" != currentDirectory &&
                        isKeyInDirectory(folderKey, true, currentDirectory)) {
                      return FolderItem(
                        folderKey: folderKey,
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  } else {
                    // Render file items
                    int fileIndex = index - folderList.length;
                    String fileKey = data.contents?[fileIndex].key ?? "";
                    if (fileKey.contains(".blazed-placeholder")) {
                      return const SizedBox.shrink();
                    }
                    if (isKeyInDirectory(fileKey, false, currentDirectory)) {
                      return FileItem(
                        fileKey: fileKey,
                      );
                    } else {
                      return const SizedBox
                          .shrink(); // Skip file items as needed
                    }
                  }
                },
              ),
            ),
          ]);
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (err, stack) {
          logger.e("Error loading file list: $err");
          return Center(
            child: Text("Error: $err"),
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              // show dialog to create a new folder
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Create folder'),
                  content: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Folder name',
                    ),
                    onChanged: (value) {
                      ref.read(newFolderNameProvider.notifier).state = value;
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        // create new folder key by combining current directory and new folder name
                        final String newFolderKey =
                            "${ref.read(currentDirectoryProvider.notifier).state}${ref.read(newFolderNameProvider.notifier).state}";
                        logger.i(
                            'Creating folder ${ref.read(newFolderNameProvider.notifier).state}');
                        createFolder(newFolderKey).then((success) {
                          ref.invalidate(fileListProvider(""));
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Created folder ${ref.read(newFolderNameProvider.notifier).state}'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Error creating folder ${ref.read(newFolderNameProvider.notifier).state}'),
                              ),
                            );
                          }
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              uploadController
                  .selectFilesToUpload(ref.read(currentDirectoryProvider));
            },
            child: const Icon(Icons.file_upload),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

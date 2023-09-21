import 'package:blazedcloud/models/transfers/download_state.dart';
import 'package:blazedcloud/models/transfers/upload_state.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStates = ref.watch(downloadStateProvider);
    final uploadStates = ref.watch(uploadStateProvider);
    final transfers = [...downloadStates, ...uploadStates];

    return ListView.builder(
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];

        if (transfer is DownloadState) {
          return Card(
            child: ListTile(
              title: Text(getFileName(transfer.downloadKey)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Progress: ${(transfer.progress * 100).toStringAsFixed(2)}%'),
                  transfer.isError
                      ? Text('Error: ${transfer.errorMessage}')
                      : transfer.isDownloading
                          ? const Text('Downloading...')
                          : const Text('Downloaded'),
                ],
              ),
            ),
          );
        } else if (transfer is UploadState) {
          return Card(
            child: ListTile(
              title: Text(getFileName(transfer.uploadKey)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Progress: ${(transfer.progress * 100).toStringAsFixed(2)}%'),
                  transfer.isError
                      ? Text('Error: ${transfer.errorMessage}')
                      : transfer.isUploading
                          ? const Text('Uploading...')
                          : const Text('Uploaded'),
                ],
              ),
            ),
          );
        }
        return null;
      },
    );
  }
}

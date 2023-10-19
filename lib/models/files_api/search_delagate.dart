import 'package:blazedcloud/models/files_api/list_files.dart';
import 'package:blazedcloud/pages/files/search_item.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';

class FileSearchDelegate extends SearchDelegate {
  final ListBucketResult list;

  FileSearchDelegate(this.list);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = "";
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return productSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return productSearchResults();
  }

  ListView productSearchResults() {
    return ListView(
      children: [
        ...fuzzySearch(query, getKeysFromList(list, false))
            .map((e) => SearchItem(fileKey: getStartingDirectory() + e))
      ],
    );
  }
}

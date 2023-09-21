import 'package:blazedcloud/pages/files/file_page.dart';
import 'package:blazedcloud/pages/settings/settings.dart';
import 'package:blazedcloud/pages/sharing/sharing.dart';
import 'package:blazedcloud/pages/transfers/transfers.dart';
import 'package:flutter/material.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int currentPageIndex = 0;
  bool didInitRateMyApp = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //resizeToAvoidBottomInset: false,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.folder),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.pending),
            label: 'Transfers',
          ),
          NavigationDestination(
            icon: Icon(Icons.share),
            label: 'Sharing',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: <Widget>[
        Container(
          alignment: Alignment.center,
          child: const FilesPage(),
        ),
        Container(
          alignment: Alignment.center,
          child: const TransfersPage(),
        ),
        Container(
          alignment: Alignment.center,
          child: const ShareScreen(),
        ),
        Container(
          alignment: Alignment.center,
          child: const SettingsScreen(),
        ),
      ][currentPageIndex],
    );
  }
}

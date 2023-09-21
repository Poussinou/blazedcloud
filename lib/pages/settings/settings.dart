import 'package:babstrap_settings_screen/babstrap_settings_screen.dart';
import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/main.dart';
import 'package:blazedcloud/pages/settings/custom_babstrap/settingsGroup.dart';
import 'package:blazedcloud/pages/settings/custom_babstrap/settingsItem.dart';
import 'package:blazedcloud/providers/pb_providers.dart';
import 'package:blazedcloud/providers/setting_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SharedPreferences prefs;
    SharedPreferences.getInstance().then((value) => {
          prefs = value,
        });
    final userData = ref.watch(accountUserProvider(pb.authStore.model.id));
    final isPremium = ref.watch(premiumProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      backgroundColor: context.isDarkMode ? Colors.black : Colors.blueGrey[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomSettingsGroup(
                items: [
                  CustomSettingsItem(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Change Name'),
                            content: TextFormField(
                              decoration: const InputDecoration(
                                hintText: 'Enter your name',
                              ),
                              initialValue:
                                  ref.read(nameProvider.notifier).state,
                              onChanged: (value) =>
                                  ref.read(nameProvider.notifier).state = value,
                            ),
                            actions: [
                              TextButton(
                                child: const Text('CANCEL'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: const Text('SAVE'),
                                onPressed: () => Navigator.of(context)
                                    .pop(ref.read(nameProvider.notifier).state),
                              ),
                            ],
                          );
                        },
                      ).then((value) async {
                        if (value != null) {
                          // update name in pocketbase
                          try {
                            await pb
                                .collection('users')
                                .update(pb.authStore.model.id, body: {
                              'username': value,
                            });
                            ref.invalidate(
                                accountUserProvider(pb.authStore.model.id));
                          } catch (e) {
                            // show snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update name'),
                              ),
                            );
                          }
                        }
                      });
                    },
                    icons: CupertinoIcons.person,
                    iconStyle: IconStyle(),
                    title: 'Change Name',
                    subtitle: "Help friends identify you",
                  ),
                ],
              ),
              CustomSettingsGroup(
                items: [
                  CustomSettingsItem(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                                'Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                child: const Text('CANCEL'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: const Text('SIGN OUT'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      ).then((value) async {
                        if (value != null) {
                          // sign out
                          await Hive.deleteBoxFromDisk('vaultBox');
                          await Hive.deleteBoxFromDisk('points');
                          await Hive.deleteBoxFromDisk('history');
                          await const FlutterSecureStorage()
                              .delete(key: 'key')
                              .then((value) {
                            pb.authStore.clear();
                            context.go('/');
                          });
                        }
                      });
                    },
                    icons: Icons.exit_to_app_rounded,
                    title: "Sign Out",
                  ),
                  CustomSettingsItem(
                    onTap: () {
                      // ask the user to confirm
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Delete account'),
                            content: Text(isPremium
                                ? 'Are you sure you want to delete your account? This is irreversible.\n\nPlease note, you will need to cancel your subscription through the app store manually'
                                : 'Are you sure you want to delete your account? This is irreversible.'),
                            actions: [
                              TextButton(
                                child: const Text('CANCEL'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: const Text('DELETE'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      ).then((value) {
                        if (value != null) {
                          // delete account
                          try {
                            pb
                                .collection('users')
                                .delete(pb.authStore.model.id);
                            pb.authStore.clear();
                            context.go('/');

                            // show dialog
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Account deleted'),
                                  content: const Text(
                                      'Your account has been deleted.'),
                                  actions: [
                                    TextButton(
                                      child: const Text('OK'),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ],
                                );
                              },
                            );
                          } catch (e) {
                            // show snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to delete account'),
                              ),
                            );
                          }
                        }
                      });
                    },
                    icons: CupertinoIcons.delete_solid,
                    title: "Delete account",
                    titleStyle: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

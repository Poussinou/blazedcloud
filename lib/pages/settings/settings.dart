import 'package:babstrap_settings_screen/babstrap_settings_screen.dart';
import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/main.dart';
import 'package:blazedcloud/pages/settings/custom_babstrap/settingsGroup.dart';
import 'package:blazedcloud/pages/settings/custom_babstrap/settingsItem.dart';
import 'package:blazedcloud/providers/pb_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      HapticFeedback.mediumImpact();
                      userData.whenData((value) => pb
                              .collection('users')
                              .requestPasswordReset(pb.authStore.model.email)
                              .then((value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Password reset email sent!")));
                            Navigator.of(context).pop();
                          }).onError((error, stackTrace) {
                            logger.e(
                                "Error sending password reset email: $error");
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Error sending password reset email")));
                            return null;
                          }));
                    },
                    icons: CupertinoIcons.lock_shield_fill,
                    iconStyle: IconStyle(),
                    title: 'Change Password',
                    subtitle:
                        "Will send a link to your email to reset your password",
                  ),
                  CustomSettingsItem(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      userData.whenData((value) => pb
                              .collection('users')
                              .requestEmailChange(pb.authStore.model.email)
                              .then((value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Request Sent!")));
                            Navigator.of(context).pop();
                          }).onError((error, stackTrace) {
                            logger.e("Error sending request: $error");
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Error sending request")));
                            return null;
                          }));
                    },
                    icons: CupertinoIcons.at,
                    iconStyle: IconStyle(),
                    title: 'Change Email',
                    subtitle:
                        "Will send a link to your email to complete the change",
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
                          await const FlutterSecureStorage()
                              .delete(key: 'key')
                              .then((value) {
                            pb.authStore.clear();
                            context.go('/landing');
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
                            context.go('/landing');

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

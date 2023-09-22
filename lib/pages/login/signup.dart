import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final emailController = TextEditingController();
final passwordController = TextEditingController();

class SignUpScreen extends ConsumerWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign up'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email Input
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
            ),

            // Password Input
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
              ),
            ),

            // Login Button
            ElevatedButton(
              onPressed: () {
                final body = <String, dynamic>{
                  "email": emailController.text,
                  "emailVisibility": false,
                  "password": passwordController.text,
                  "passwordConfirm": passwordController.text,
                  "active": false,
                  "capacity_gigs": 5,
                  "usingPersonalEncryption": false
                };

                try {
                  pb.collection('users').create(body: body).then((value) {
                    pb
                        .collection('users')
                        .requestVerification(emailController.text);

                    // we need to login now after creating the user
                    pb
                        .collection('users')
                        .authWithPassword(
                          emailController.text,
                          passwordController.text,
                        )
                        .then((value) {
                      pb.authStore.save(value.token, value.record);

                      if (pb.authStore.isValid) {
                        context.go('/dashboard');
                      }
                    });
                  }).onError((error, stackTrace) {
                    logger.e(error);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Invalid email or password")));
                    return Future.value(null);
                  });
                } catch (e) {
                  logger.e(e);
                }
              },
              child: const Text('Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}

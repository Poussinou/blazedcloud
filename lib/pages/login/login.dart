import 'package:blazedcloud/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final emailController = TextEditingController();
final passwordController = TextEditingController();

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Page'),
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
                // attempt login with pocketbase
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
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

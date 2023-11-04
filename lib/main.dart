import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/pocketbase/authstore.dart';
import 'package:blazedcloud/pages/dashboard.dart';
import 'package:blazedcloud/pages/login/login.dart';
import 'package:blazedcloud/pages/login/signup.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:pocketbase/pocketbase.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  runApp(const MyApp());
}

final healthCheckProvider = FutureProvider.autoDispose<bool>((ref) async {
  logger.i("Checking health");
  final health = await pb.health.check();
  logger.i("Health check result: $health");
  return health.code == 200;
});

final savedAuthProvider = FutureProvider.autoDispose<bool>((ref) async {
  final customAuth = CustomAuthStore();

  final auth = await customAuth.loadAuth();
  if (auth != null) {
    logger.i("Loaded auth: $auth");
    pb = PocketBase(backendUrl, authStore: auth);
    if (pb.authStore.isValid) {
      logger.i("Token is valid. User: ${pb.authStore.model.id}");
    }
  } else {
    logger.i("No saved auth");
  }

  return auth != null && pb.authStore.isValid;
});

// GoRouter configuration
final _router = GoRouter(
  initialLocation: '/landing',
  routes: [
    GoRoute(
      path: '/landing',
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      name: "login",
      path: '/landing/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      name: "signup",
      path: '/landing/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      name: "dashboard",
      path: '/dashboard',
      builder: (context, state) => const Dashboard(),
    ),
  ],
);

class LandingContent extends StatelessWidget {
  const LandingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Blazed Cloud",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 50)),
          Lottie.asset("assets/lottie/fire.json", repeat: true),
          ElevatedButton(
            onPressed: () {
              context.pushNamed('login');
            },
            style: const ButtonStyle(),
            child: const Text(
              'Login',
              style: TextStyle(fontSize: 30),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.pushNamed('signup');
            },
            style: const ButtonStyle(),
            child: const Text(
              'Sign up',
              style: TextStyle(fontSize: 30),
            ),
          ),
        ],
      ),
    ));
  }
}

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // check server health then check if user is logged in
    return ref.watch(healthCheckProvider).when(
      data: (data) {
        return ref.watch(savedAuthProvider).when(
          data: (data) {
            if (data) {
              logger.d("Token is valid. User: ${pb.authStore.model.id}");
              return const Dashboard();
            } else {
              return const LandingContent();
            }
          },
          loading: () {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          error: (err, stack) {
            logger.i("Error loading saved auth: $err");

            // clear saved auth
            Hive.deleteBoxFromDisk('vaultBox');
            const FlutterSecureStorage().delete(key: 'key');

            return const LandingContent();
          },
        );
      },
      loading: () {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (err, stack) {
        logger.e("Server Health check failed: $err");
        return FutureBuilder(
            future: getExportDirectory(false),
            builder: (context, snapshot) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Wrap(
                          children: [
                            Column(
                              children: [
                                const Text(
                                    "Server is currently undergoing maintenance. Please try again later."),
                                if (snapshot.hasData && snapshot.data != '')
                                  Text(
                                      "Offline files are stored at ${snapshot.data}"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
        child: MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        /* light theme settings */
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        /* dark theme settings */
      ),
    ));
  }
}

extension DarkMode on BuildContext {
  /// is dark mode currently enabled?
  bool get isDarkMode {
    final brightness = MediaQuery.of(this).platformBrightness;
    return brightness == Brightness.dark;
  }
}

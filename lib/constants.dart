import 'package:pocketbase/pocketbase.dart';

import 'models/pocketbase.dart';

// localhost
//const String backendUrl = "http://10.0.2.2:8090";
// lan
const String backendUrl = "http://192.168.68.50:8090";
// tests
//const String backendUrl = "http://127.0.0.1:8090";
// dev
//const String backendUrl = "https://angry-diamond.pockethost.io";
// prod
//const String backendUrl = "https://dietly-pb.fly.dev";

var pb = PocketBase(backendUrl, authStore: CustomAuthStore());

import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox("database");
  runApp(MyApp(box: box));
}

class MyApp extends StatefulWidget {
  final Box box;
  const MyApp({super.key, required this.box});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Box box;
  @override
  void initState() {
    super.initState();
    box = widget.box;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
        theme: const CupertinoThemeData(primaryColor: CupertinoColors.label),
        debugShowCheckedModeBanner: false,
        home: (box.get("username") == null)
            ? Signup(box: box)
            : Homepage(box: box));
  }
}

// ... (Imports and main remain the same)

class Homepage extends StatefulWidget {
  final Box box;
  const Homepage({super.key, required this.box});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final LocalAuthentication auth = LocalAuthentication();
  late final Box box;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    box = widget.box;
  }

  Future<void> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to login',
      );
      if (didAuthenticate) {
        setState(() {
          _username.text = box.get("username") ?? '';
          _password.text = box.get("password") ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF121212), // Spotify Dark Background
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_house_fill, size: 80, color: Color(0xFF1DB954)),
                const SizedBox(height: 20),
                const Text(
                  'Millions of songs.\nFree on Spotify.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 40),
                CupertinoTextField(
                  controller: _username,
                  padding: const EdgeInsets.all(16),
                  placeholder: "Email or username",
                  placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
                  style: const TextStyle(color: CupertinoColors.white),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _password,
                  padding: const EdgeInsets.all(16),
                  placeholder: "Password",
                  obscureText: hidePassword,
                  placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
                  style: const TextStyle(color: CupertinoColors.white),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      hidePassword ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                      color: CupertinoColors.systemGrey,
                    ),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFF1DB954), // Spotify Green
                    borderRadius: BorderRadius.circular(30),
                    child: const Text(
                      'Log In',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    onPressed: () {
                      if (_username.text.trim() == box.get("username") &&
                          _password.text.trim() == box.get("password")) {
                        Navigator.pushReplacement(
                          context,
                          CupertinoPageRoute(builder: (context) => Home(box: box)),
                        );
                      } else {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text("Login Failed"),
                            content: const Text("Check your credentials and try again."),
                            actions: [
                              CupertinoButton(
                                child: const Text("OK"),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 15),
                if (box.get("biometrics") == true)
                  CupertinoButton(
                    child: const Icon(Icons.fingerprint, size: 40, color: Color(0xFF1DB954)),
                    onPressed: () => authenticate(),
                  ),
                CupertinoButton(
                  child: const Text('Erase Data', style: TextStyle(color: CupertinoColors.systemGrey)),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        content: const Text("Are you sure to delete all data?"),
                        actions: [
                          CupertinoButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
                          CupertinoButton(
                            child: const Text("Yes", style: TextStyle(color: CupertinoColors.destructiveRed)),
                            onPressed: () {
                              box.clear();
                              Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => Signup(box: box)));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Signup extends StatefulWidget {
  final Box box;
  const Signup({super.key, required this.box});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  late final Box box;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    box = widget.box;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF121212),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note_2, size: 60, color: Color(0xFF1DB954)),
                const SizedBox(height: 20),
                const Text(
                  'Sign up for free to\nstart listening.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("What's your email?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _username,
                  padding: const EdgeInsets.all(16),
                  style: const TextStyle(color: CupertinoColors.white),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Create a password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _password,
                  padding: const EdgeInsets.all(16),
                  obscureText: hidePassword,
                  style: const TextStyle(color: CupertinoColors.white),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      hidePassword ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                      color: CupertinoColors.systemGrey,
                    ),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 200,
                  child: CupertinoButton(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(30),
                    child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    onPressed: () async {
                      await box.put("username", _username.text.trim());
                      await box.put("password", _password.text.trim());
                      await box.put("biometrics", false);

                      if (!mounted) return;
                      Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => Homepage(box: box)));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ... (Rest of the Home, HomeList, PlanPage, PaymentPage, and Settings remain the same)
class Home extends StatefulWidget {
  final Box box;
  const Home({super.key, required this.box});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(items: const [
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.star), label: "Plan"),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: "Settings"),
      ]),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return HomeList(box: widget.box);
          case 1:
            return PlanPage(box: widget.box);
          default:
            return Settings(box: widget.box);
        }
      },
    );
  }
}

class HomeList extends StatefulWidget {
  final Box box;
  const HomeList({super.key, required this.box});

  @override
  State<HomeList> createState() => _HomeListState();
}

class _HomeListState extends State<HomeList> {
  late final Box box;
  bool isDark = true;

  String currentSong = "Ale";
  String currentArtist = "The Bloomfields";
  String albumArt =
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTPsUJznruWzz5d-FtqBZ8aOuk-rPbPFFjyzw&s";
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    box = widget.box;
  }

  Widget miniPlayer() {
    final bgColor = isDark ? const Color(0xFF181818) : CupertinoColors.systemGrey6;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final subTextColor = isDark ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey;
    final iconColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(albumArt, width: 52, height: 52, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentSong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                        const SizedBox(height: 2),
                        Text(currentArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: subTextColor)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(CupertinoIcons.backward_fill, size: 22, color: iconColor),
                          onPressed: () {}),
                      CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(
                              isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                              size: 42,
                              color: iconColor),
                          onPressed: () {
                            setState(() {
                              isPlaying = !isPlaying;
                            });
                          }),
                      CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(CupertinoIcons.forward_fill, size: 22, color: iconColor),
                          onPressed: () {}),
                    ],
                  )
                ],
              ),
            ),
          ),
          Container(
            height: 2,
            width: double.infinity,
            color: isDark ? CupertinoColors.systemGrey4 : CupertinoColors.systemGrey2,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.35,
              child: Container(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(String title, String imageUrl) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [CupertinoColors.black.withOpacity(0.6), CupertinoColors.systemGrey.withOpacity(0.0)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(title,
              style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }

  List<String> getBenefits(String currentPlan) {
    if (currentPlan == "Free") {
      return ["- Listen with ads", "- Limited skips", "- Only on one device"];
    } else {
      return ["- Listen to music ad-free", "- Download songs offline", "- Play on any device", "- Unlimited skips"];
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.label;

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, _) {
        final String username = box.get("username") ?? "Sage";
        final String currentPlan = box.get("plan") ?? "Free";
        final double pricePaid = box.get("pricePaid") ?? 0.0;
        final String planExpiry = box.get("planExpiry") ?? "No expiry";

        return CupertinoPageScaffold(
          child: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Hello, $username",
                                style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text("Enjoy your music experience",
                                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
                          ],
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(
                                  "https://i.pinimg.com/736x/a4/71/31/a47131039ecbeffaf3ba573730976eb8.jpg"),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [CupertinoColors.systemGreen, CupertinoColors.systemTeal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Your Plan",
                              style: TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(currentPlan,
                              style: const TextStyle(color: CupertinoColors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("Price Paid: ₱$pricePaid", style: const TextStyle(color: CupertinoColors.white, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Valid until: $planExpiry", style: const TextStyle(color: CupertinoColors.white, fontSize: 16)),
                          const SizedBox(height: 16),
                          const Text("Benefits",
                              style: TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ...getBenefits(currentPlan).map((b) => Text(b, style: const TextStyle(color: CupertinoColors.white))).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _featureCard("Recommended Playlist", "https://encrypted-tbn2.gstatic.com/images?q=tbn:ANd9GcQ_CL_vmiqJmPosWnL6BQ_ccnCKo0_vGRZR5wLL64i3MrLaPM8X"),
                          _featureCard("Top Charts", "https://i.scdn.co/image/ab676161000051744aac2151be750fecb674048a"),
                          _featureCard("New Releases", "https://pickasso.spotifycdn.com/image/ab67c0de0000deef/dt/v1/img/thisisv3/1UwnrHfh8Kd8Y8Ax8a3qWy/en"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _featureCard("Radio", "https://pickasso.spotifycdn.com/image/ab67c0de0000deef/dt/v1/img/radio/artist/2kxP07DLgs4xlWz8YHlvfh/de"),
                          _featureCard("Your Favorites", "https://pickasso.spotifycdn.com/image/ab67c0de0000deef/dt/v1/img/thisisv3/6Dp4LInLyMVA2qhRqQ6AGL/en"),
                          _featureCard("Trending Now", "https://preview.redd.it/walang-ibang-gugustuhin-kundi-ikaw-v0-ki3o8ath5z2d1.jpeg?auto=webp&s=869e87669e1d25f25e78d8e2eca2f5642e72a062"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: miniPlayer()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PlanPage extends StatefulWidget {
  final Box box;
  const PlanPage({super.key, required this.box});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late final Box box;

  @override
  void initState() {
    super.initState();
    box = widget.box;
  }

  Future<void> payNow(BuildContext context, String planName, int price, String duration) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text("Connecting"),
        content: CupertinoActivityIndicator(),
      ),
    );

    String secretKey = "xnd_development_GLxc5Y02G2w5Sh2KjMVUUDKRcrHao7tgPNYAoE9TkgIPlZuKtczqjk9ZNIV";
    String auth = 'Basic ${base64Encode(utf8.encode('$secretKey:'))}';
    const url = "https://api.xendit.co/v2/invoices/";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Authorization": auth, "Content-Type": "application/json"},
        body: jsonEncode({
          "external_id": "sub_${DateTime.now().millisecondsSinceEpoch}",
          "amount": price,
          "description": "Spotify $planName Subscription",
          "success_redirect_url": "https://dashboard.xendit.co/success",
        }),
      );

      final data = jsonDecode(response.body);
      String invoiceUrl = data['invoice_url'];

      if (!mounted) return;
      Navigator.pop(context); // Close connecting dialog

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => PaymentPage(
            url: invoiceUrl,
            onPaid: () async {
              // SAVE DATA HERE
              await box.put("plan", planName);
              await box.put("pricePaid", price.toDouble());
              await box.put("planExpiry", duration);

              if (!mounted) return;
              Navigator.pop(context); // Close WebView

              showCupertinoDialog(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text("Success"),
                  content: Text("Subscription to $planName active!"),
                  actions: [
                    CupertinoButton(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))
                  ],
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      debugPrint("Error: $e");
    }
  }

  Widget planTile(BuildContext context, String planName, String price, String duration) {
    return GestureDetector(
      onTap: () => payNow(context, planName, int.parse(price), duration),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [CupertinoColors.systemGreen, CupertinoColors.systemTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(planName,
                style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("₱$price", style: const TextStyle(color: CupertinoColors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(duration, style: const TextStyle(color: CupertinoColors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("Choose Your Plan")),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              planTile(context, "Individual", "199", "1 Month"),
              planTile(context, "Duo", "299", "1 Month"),
              planTile(context, "Family", "349", "1 Month"),
              planTile(context, "Student", "99", "1 Month"),
              planTile(context, "Premium 3 Months", "549", "3 Months"),
              planTile(context, "Premium 6 Months", "999", "6 Months"),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  final String url;
  final Future<void> Function() onPaid;

  const PaymentPage({super.key, required this.url, required this.onPaid});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late WebViewController controller;
  bool isFinished = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) async {
            final url = change.url ?? "";
            if (url.contains("success") || url.contains("completed") || url.contains("callback")) {
              if (!isFinished) {
                isFinished = true;
                await widget.onPaid();
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("Payment")),
      child: WebViewWidget(controller: controller),
    );
  }
}

class Settings extends StatefulWidget {
  final Box box;
  const Settings({super.key, required this.box});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Widget tiles(Color color, String title, dynamic trailing, IconData icon) {
    return CupertinoListTile(
        trailing: trailing,
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: color,
          ),
          child: Icon(icon, size: 17, color: CupertinoColors.white),
        ),
        title: Text(title));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            children: [
              tiles(
                  CupertinoColors.systemPurple,
                  "Biometrics",
                  CupertinoSwitch(
                      value: widget.box.get("biometrics") ?? false,
                      onChanged: (value) {
                        setState(() {
                          widget.box.put("biometrics", value);
                        });
                      }),
                  Icons.fingerprint_rounded),
              GestureDetector(
                  onTap: () {
                    showCupertinoDialog(
                        context: context,
                        builder: (context) {
                          return CupertinoAlertDialog(
                            title: const Text("Sign out?"),
                            actions: [
                              CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Text("Cancel"),
                                  onPressed: () => Navigator.pop(context)),
                              CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Text("Yes"),
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                        context,
                                        CupertinoPageRoute(
                                            builder: (context) =>
                                                Homepage(box: widget.box)));
                                  }),
                            ],
                          );
                        });
                  },
                  child: tiles(CupertinoColors.destructiveRed, "Signout",
                      const Icon(CupertinoIcons.chevron_forward), Icons.logout))
            ],
          )
        ],
      ),
    );
  }
}
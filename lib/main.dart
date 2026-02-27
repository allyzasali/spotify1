import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, LinearProgressIndicator, Icons, CircleAvatar, Material, Colors, BoxDecoration, BoxShadow, Border, BorderRadius, Positioned, Stack, ClipRRect, Image, NetworkImage, Text, TextStyle, FontWeight, EdgeInsets, SizedBox, Row, Column, Expanded, Container, SingleChildScrollView, ListView, Padding, Center, Icon, GestureDetector, MainAxisAlignment, CrossAxisAlignment;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('orders');
  await Hive.openBox('restaurants');
  await Hive.openBox('menu_items');
  runApp(const QuickBiteApp());
}

class QuickBiteApp extends StatefulWidget {
  const QuickBiteApp({super.key});

  @override
  State<QuickBiteApp> createState() => _QuickBiteAppState();
}

class _QuickBiteAppState extends State<QuickBiteApp> {
  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickBite',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeGreen,
        barBackgroundColor: CupertinoColors.white,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      home: SplashScreen(),
    );
  }
}

// --- LOCATION CONSTANTS ---
class LocationConstants {
  // SM Pampanga (San Fernando, Pampanga) - Your Restaurant/Point A
  static const LatLng smPampanga = LatLng(15.0289, 120.6856); // SM City Pampanga

  // Default delivery locations in Pampanga (Point B examples)
  static const Map<String, LatLng> pampangaLocations = {
    'Angeles City': LatLng(15.1394, 120.5927),
    'San Fernando': LatLng(15.0289, 120.6856),
    'Clark': LatLng(15.1851, 120.5597),
    'Mexico': LatLng(15.0649, 120.7203),
    'Arayat': LatLng(15.1505, 120.7694),
    'Mabalacat': LatLng(15.2230, 120.5792),
  };
}

// --- MODELS ---
class FoodItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final int prepTime;
  final double rating;
  final String restaurantId;
  final bool isAvailable;

  FoodItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.prepTime,
    required this.rating,
    required this.restaurantId,
    required this.isAvailable,
  });
}

class Restaurant {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final int deliveryTime;
  final double deliveryFee;
  final double minOrder;
  final bool isOpen;
  final LatLng location;
  final String cuisine;
  final String address;

  Restaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.minOrder,
    required this.isOpen,
    required this.location,
    required this.cuisine,
    required this.address,
  });
}

class CartItem {
  final FoodItem foodItem;
  final int quantity;

  CartItem({
    required this.foodItem,
    required this.quantity,
  });

  double get totalPrice => foodItem.price * quantity;
}

// --- OPENSTREETMAP ROUTING SERVICE ---
class OSRMRoutingService {
  static const String _baseUrl = 'https://routing.openstreetmap.de/routed-car/route/v1/driving/';

  static Future<OSMRoute?> getRoute(LatLng start, LatLng end) async {
    try {
      // Format: {lon},{lat};{lon},{lat}
      final url = '${_baseUrl}${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true';

      print('🌍 Fetching route from: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Route request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] == 'Ok') {
          final route = data['routes'][0];

          // Extract polyline points from GeoJSON
          final coordinates = route['geometry']['coordinates'] as List;
          final List<LatLng> polyline = coordinates.map((coord) =>
              LatLng(coord[1], coord[0]) // GeoJSON is [lng, lat]
          ).toList();

          return OSMRoute(
            distance: route['distance'].toDouble(), // in meters
            duration: route['duration'].toDouble(), // in seconds
            polyline: polyline,
          );
        }
      }

      // Fallback: Return straight line if routing fails
      print('⚠️ Routing failed, using straight line fallback');
      return OSMRoute(
        distance: _calculateDistance(start, end),
        duration: _calculateDistance(start, end) / 5, // Rough estimate
        polyline: [start, end],
      );

    } catch (e) {
      print('❌ OSM Routing Error: $e');
      // Return straight line as fallback
      return OSMRoute(
        distance: _calculateDistance(start, end),
        duration: _calculateDistance(start, end) / 5,
        polyline: [start, end],
      );
    }
  }

  static double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // meters

    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final deltaLat = (end.latitude - start.latitude) * pi / 180;
    final deltaLon = (end.longitude - start.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  static String formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(0)} sec';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      return '$minutes min';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      return '${hours}h ${minutes}m';
    }
  }
}

class OSMRoute {
  final double distance; // meters
  final double duration; // seconds
  final List<LatLng> polyline;

  OSMRoute({
    required this.distance,
    required this.duration,
    required this.polyline,
  });
}

// --- GEOLOCATOR SERVICE ---
class GeolocatorService {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services to track your order.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied. Please grant location access to track your order.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable location access in settings.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<String> getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      return 'Address not available';
    }
    return 'Address not available';
  }

  static double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    ) / 1000; // Convert to kilometers
  }

  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  static String estimateArrivalTime(double distanceInKm) {
    // Assuming average delivery speed of 20 km/h in city
    double minutes = (distanceInKm / 20) * 60;
    if (minutes < 1) {
      return 'Less than a minute';
    } else if (minutes < 60) {
      return '${minutes.round()} minutes';
    } else {
      return '${(minutes / 60).round()} hour ${(minutes % 60).round()} minutes';
    }
  }
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final restaurantsBox = Hive.box('restaurants');
    if (restaurantsBox.isEmpty) {
      await _seedRestaurants();
    }

    final menuBox = Hive.box('menu_items');
    if (menuBox.isEmpty) {
      await _seedMenuItems();
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<void> _seedRestaurants() async {
    final restaurantsBox = Hive.box('restaurants');
    final restaurants = [
      {
        'id': 'r1',
        'name': 'Burger House - SM Pampanga',
        'imageUrl': 'https://images.unsplash.com/photo-1571091718767-18b5b1457add',
        'rating': 4.5,
        'deliveryTime': 25,
        'deliveryFee': 49.0,
        'minOrder': 100.0,
        'isOpen': true,
        'latitude': LocationConstants.smPampanga.latitude,
        'longitude': LocationConstants.smPampanga.longitude,
        'cuisine': 'American',
        'address': 'SM City Pampanga, San Fernando',
      },
      {
        'id': 'r2',
        'name': 'Pizza Paradise - SM Pampanga',
        'imageUrl': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38',
        'rating': 4.8,
        'deliveryTime': 30,
        'deliveryFee': 59.0,
        'minOrder': 200.0,
        'isOpen': true,
        'latitude': LocationConstants.smPampanga.latitude,
        'longitude': LocationConstants.smPampanga.longitude,
        'cuisine': 'Italian',
        'address': 'SM City Pampanga, San Fernando',
      },
      {
        'id': 'r3',
        'name': 'Sushi Master - SM Pampanga',
        'imageUrl': 'https://images.unsplash.com/photo-1553621042-f6e147245754',
        'rating': 4.7,
        'deliveryTime': 35,
        'deliveryFee': 69.0,
        'minOrder': 300.0,
        'isOpen': true,
        'latitude': LocationConstants.smPampanga.latitude,
        'longitude': LocationConstants.smPampanga.longitude,
        'cuisine': 'Japanese',
        'address': 'SM City Pampanga, San Fernando',
      },
    ];

    for (var restaurant in restaurants) {
      await restaurantsBox.put(restaurant['id'], restaurant);
    }
  }

  Future<void> _seedMenuItems() async {
    final menuBox = Hive.box('menu_items');
    final items = [
      {
        'id': 'f1',
        'name': 'Classic Burger',
        'price': 149.00,
        'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
        'description': 'Juicy beef patty with lettuce, tomato, and special sauce',
        'prepTime': 15,
        'rating': 4.5,
        'restaurantId': 'r1',
        'isAvailable': true,
      },
      {
        'id': 'f2',
        'name': 'Double Cheeseburger',
        'price': 229.00,
        'imageUrl': 'https://images.unsplash.com/photo-1553979459-d2229ba7433b',
        'description': 'Double beef patty with double cheese',
        'prepTime': 18,
        'rating': 4.7,
        'restaurantId': 'r1',
        'isAvailable': true,
      },
      {
        'id': 'f3',
        'name': 'Margherita Pizza',
        'price': 299.00,
        'imageUrl': 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca',
        'description': 'Fresh basil, mozzarella, and tomato sauce',
        'prepTime': 20,
        'rating': 4.8,
        'restaurantId': 'r2',
        'isAvailable': true,
      },
      {
        'id': 'f4',
        'name': 'Pepperoni Pizza',
        'price': 349.00,
        'imageUrl': 'https://images.unsplash.com/photo-1628840042765-356cda07504e',
        'description': 'Classic pepperoni with extra cheese',
        'prepTime': 22,
        'rating': 4.9,
        'restaurantId': 'r2',
        'isAvailable': true,
      },
      {
        'id': 'f5',
        'name': 'Sushi Platter',
        'price': 449.00,
        'imageUrl': 'https://images.unsplash.com/photo-1553621042-f6e147245754',
        'description': 'Assorted fresh sushi rolls',
        'prepTime': 25,
        'rating': 4.7,
        'restaurantId': 'r3',
        'isAvailable': true,
      },
      {
        'id': 'f6',
        'name': 'California Roll',
        'price': 199.00,
        'imageUrl': 'https://images.unsplash.com/photo-1617196035154-1e7e6e28b0db',
        'description': 'Crab, avocado, and cucumber roll',
        'prepTime': 15,
        'rating': 4.5,
        'restaurantId': 'r3',
        'isAvailable': true,
      },
    ];

    for (var item in items) {
      await menuBox.put(item['id'], item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CupertinoColors.systemGreen.withValues(alpha: 0.3), CupertinoColors.white],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.cart_fill, size: 100, color: CupertinoColors.activeGreen),
              SizedBox(height: 20),
              Text(
                'QuickBite',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              SizedBox(height: 8),
              Text(
                'Delicious food at your doorstep',
                style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              SizedBox(height: 40),
              CupertinoActivityIndicator(radius: 15),
            ],
          ),
        ),
      ),
    );
  }
}

// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showDialog('Error', 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    final usersBox = Hive.box('users');
    bool userFound = false;
    String? userId;

    for (var key in usersBox.keys) {
      final userData = usersBox.get(key);
      if (userData['email'] == _emailController.text &&
          userData['password'] == _passwordController.text) {
        userFound = true;
        userId = key.toString();
        break;
      }
    }

    setState(() => _isLoading = false);

    if (userFound && mounted) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) => HomePage(userId: userId!),
        ),
      );
    } else {
      _showDialog('Error', 'Invalid email or password');
    }
  }

  void _showDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.systemGreen.withValues(alpha: 0.1),
              CupertinoColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(
                  CupertinoIcons.cart_fill,
                  size: 80,
                  color: CupertinoColors.activeGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'QuickBite',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(CupertinoIcons.mail, color: CupertinoColors.systemGrey),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Password',
                  obscureText: _obscurePassword,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(CupertinoIcons.lock, color: CupertinoColors.systemGrey),
                  ),
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isLoading ? null : _login,
                    borderRadius: BorderRadius.circular(12),
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  child: const Text('Don\'t have an account? Sign Up'),
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const SignUpPage()),
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

// --- SIGN UP PAGE ---
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showDialog('Error', 'Please fill in all fields');
      return;
    }

    if (!_agreeToTerms) {
      _showDialog('Error', 'Please agree to terms and conditions');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    final usersBox = Hive.box('users');
    final userId = DateTime.now().millisecondsSinceEpoch.toString();

    final newUser = {
      'id': userId,
      'name': _nameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
      'phone': _phoneController.text,
      'createdAt': DateTime.now().toIso8601String(),
      'addresses': [], // Initialize empty addresses list
    };

    await usersBox.put(userId, newUser);
    await usersBox.flush();

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pop(context);
      _showDialog('Success', 'Account created successfully! You can now log in.');
    }
  }

  void _showDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Create Account'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'Full Name',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _emailController,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _phoneController,
                placeholder: 'Phone Number',
                keyboardType: TextInputType.phone,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _passwordController,
                placeholder: 'Password',
                obscureText: true,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CupertinoSwitch(
                    value: _agreeToTerms,
                    onChanged: (val) => setState(() => _agreeToTerms = val),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('I agree to the Terms and Conditions', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isLoading ? null : _signUp,
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('Register', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  final String userId;
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<FoodItem> _cart = [];
  List<Restaurant> _restaurants = [];
  List<FoodItem> _menuItems = [];
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final usersBox = Hive.box('users');
    final userData = usersBox.get(widget.userId);

    final restaurantsBox = Hive.box('restaurants');
    final loadedRestaurants = restaurantsBox.values.map((data) => Restaurant(
      id: data['id'],
      name: data['name'],
      imageUrl: data['imageUrl'],
      rating: data['rating'],
      deliveryTime: data['deliveryTime'],
      deliveryFee: data['deliveryFee'],
      minOrder: data['minOrder'],
      isOpen: data['isOpen'],
      location: LatLng(data['latitude'], data['longitude']),
      cuisine: data['cuisine'],
      address: data['address'],
    )).toList();

    final menuBox = Hive.box('menu_items');
    final loadedItems = menuBox.values.map((data) => FoodItem(
      id: data['id'],
      name: data['name'],
      price: data['price'],
      imageUrl: data['imageUrl'],
      description: data['description'],
      prepTime: data['prepTime'],
      rating: data['rating'],
      restaurantId: data['restaurantId'],
      isAvailable: data['isAvailable'],
    )).toList();

    setState(() {
      _currentUser = userData;
      _restaurants = loadedRestaurants;
      _menuItems = loadedItems;
    });
  }

  void _addToCart(FoodItem item) {
    setState(() => _cart.add(item));
  }

  void _removeFromCart(FoodItem item) {
    setState(() {
      final index = _cart.indexWhere((element) => element.id == item.id);
      if (index != -1) {
        _cart.removeAt(index);
      }
    });
  }

  int _getItemCount(String itemId) {
    return _cart.where((item) => item.id == itemId).length;
  }

  Future<void> _logout() async {
    final shouldLogout = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('Logout'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('QuickBite - SM Pampanga', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ProfilePage(userId: widget.userId, userData: _currentUser, onLogout: _logout))),
          child: const Icon(CupertinoIcons.person_circle),
        ),
        trailing: Stack(
          alignment: Alignment.center,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _cart.isEmpty ? null : () => Navigator.push(context, CupertinoPageRoute(builder: (_) => CheckoutPage(cart: _cart, userId: widget.userId, onOrderPlaced: () => setState(() => _cart.clear())))),
              child: const Icon(CupertinoIcons.cart_fill, color: CupertinoColors.activeGreen),
            ),
            if (_cart.isNotEmpty)
              Positioned(
                right: 0,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: CupertinoColors.destructiveRed, shape: BoxShape.circle),
                  child: Text('${_cart.length}', style: const TextStyle(fontSize: 10, color: CupertinoColors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [CupertinoColors.activeGreen, CupertinoColors.activeGreen.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome!', style: TextStyle(color: CupertinoColors.white, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_currentUser?['name'] ?? 'User', style: const TextStyle(color: CupertinoColors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Restaurants at SM Pampanga', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._restaurants.map((r) => _buildRestaurantCard(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant r) {
    final items = _menuItems.where((i) => i.restaurantId == r.id).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: CupertinoColors.systemGrey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(r.imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 160, color: CupertinoColors.systemGrey6, child: const Icon(CupertinoIcons.photo, size: 50))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: CupertinoColors.systemYellow.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(CupertinoIcons.star_fill, size: 14, color: CupertinoColors.systemYellow), const SizedBox(width: 4), Text(r.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold))])),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${r.cuisine} • ${r.deliveryTime} mins • ₱${r.deliveryFee} fee', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
                const SizedBox(height: 16),
                const Text('Menu Highlights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...items.map((i) => _buildMenuItem(i)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(FoodItem i) {
    final count = _getItemCount(i.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              i.imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("₱${i.price}", style: const TextStyle(color: CupertinoColors.activeGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          if (count == 0)
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              borderRadius: BorderRadius.circular(20),
              onPressed: () => _addToCart(i),
              child: const Text("Add"),
            )
          else
            Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _removeFromCart(i),
                  child: const Icon(CupertinoIcons.minus_circle_fill, color: CupertinoColors.destructiveRed),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _addToCart(i),
                  child: const Icon(CupertinoIcons.plus_circle_fill, color: CupertinoColors.activeGreen),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// --- PROFILE PAGE ---
class ProfilePage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? userData;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.userId, required this.userData, required this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<String> _addresses = [];
  List<Map<String, dynamic>> _userOrders = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final usersBox = Hive.box('users');
    final userData = usersBox.get(widget.userId);
    setState(() {
      _addresses = List<String>.from(userData['addresses'] ?? []);
    });

    final ordersBox = Hive.box('orders');
    setState(() {
      _userOrders = ordersBox.values
          .where((order) => order['userId'] == widget.userId)
          .map((order) => Map<String, dynamic>.from(order))
          .toList();
    });
  }

  void _showAddressDialog(BuildContext context) {
    final TextEditingController addressController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          height: 400,
          decoration: const BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey.withValues(alpha: 0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.xmark),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _addresses.length) {
                      return CupertinoButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _addNewAddress(context, addressController);
                        },
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.add, color: CupertinoColors.activeGreen),
                            SizedBox(width: 8),
                            Text('Add New Address'),
                          ],
                        ),
                      );
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.location_fill, size: 16, color: CupertinoColors.activeGreen),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_addresses[index])),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _deleteAddress(context, index),
                            child: const Icon(CupertinoIcons.delete, size: 18, color: CupertinoColors.destructiveRed),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewAddress(BuildContext context, TextEditingController controller) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Enter your address',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              controller.clear();
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final usersBox = Hive.box('users');
                final userData = Map<String, dynamic>.from(usersBox.get(widget.userId));
                final addresses = List<String>.from(userData['addresses'] ?? []);
                addresses.add(controller.text);
                userData['addresses'] = addresses;
                await usersBox.put(widget.userId, userData);

                setState(() {
                  _addresses = addresses;
                });

                controller.clear();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Close both dialogs
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _deleteAddress(BuildContext context, int index) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              final usersBox = Hive.box('users');
              final userData = Map<String, dynamic>.from(usersBox.get(widget.userId));
              final addresses = List<String>.from(userData['addresses'] ?? []);
              addresses.removeAt(index);
              userData['addresses'] = addresses;
              await usersBox.put(widget.userId, userData);

              setState(() {
                _addresses = addresses;
              });

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showOrderHistory(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          height: 500,
          decoration: const BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey.withValues(alpha: 0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.xmark),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _userOrders.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.clock, size: 50, color: CupertinoColors.systemGrey),
                      SizedBox(height: 16),
                      Text('No orders yet', style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey)),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userOrders.length,
                  itemBuilder: (context, index) {
                    final order = _userOrders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: order['status'] == 'Delivered'
                                      ? CupertinoColors.activeGreen.withValues(alpha: 0.1)
                                      : order['status'] == 'Paid'
                                      ? CupertinoColors.systemBlue.withValues(alpha: 0.1)
                                      : CupertinoColors.systemYellow.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  order['status'] ?? 'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: order['status'] == 'Delivered'
                                        ? CupertinoColors.activeGreen
                                        : order['status'] == 'Paid'
                                        ? CupertinoColors.systemBlue
                                        : CupertinoColors.systemYellow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total: ₱${order['total']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(DateTime.parse(order['orderTime']).toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Items: ${order['items']?.length ?? 0} item(s)', style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                          if (order['status'] == 'Paid' || order['status'] == 'On the way' || order['status'] == 'Preparing')
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => OrderTrackingPage(
                                      orderId: order['id'],
                                      userId: widget.userId, // Pass the userId
                                      onBackToHome: () => Navigator.popUntil(context, (r) => r.isFirst),
                                    ),
                                  ),
                                );
                              },
                              child: const Row(
                                children: [
                                  Icon(CupertinoIcons.location_fill, size: 16),
                                  SizedBox(width: 4),
                                  Text('Track Order'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Profile'),
        backgroundColor: CupertinoColors.white,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CupertinoColors.activeGreen, Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.activeGreen.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: CupertinoColors.white,
                child: Text(
                  widget.userData?['name']?[0] ?? 'U',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.activeGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.userData?['name'] ?? 'User',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.userData?['email'] ?? '',
              style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildProfileTile(
                    icon: CupertinoIcons.location,
                    title: 'My Addresses',
                    subtitle: _addresses.isEmpty ? 'Add your delivery address' : '${_addresses.length} address(es)',
                    onTap: () => _showAddressDialog(context),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileTile(
                    icon: CupertinoIcons.clock,
                    title: 'Order History',
                    subtitle: _userOrders.isEmpty ? 'No orders yet' : '${_userOrders.length} order(s)',
                    onTap: () => _showOrderHistory(context),
                  ),
                  const SizedBox(height: 20),
                  _buildLogoutButton(widget.onLogout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.activeGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: CupertinoColors.activeGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward, size: 16, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(VoidCallback onLogout) {
    return GestureDetector(
      onTap: onLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.systemRed.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.square_arrow_left, size: 20, color: CupertinoColors.systemRed),
            const SizedBox(width: 8),
            Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.systemRed)),
          ],
        ),
      ),
    );
  }
}

// --- XENDIT PAYMENT SERVICE ---
class XenditService {
  static const String _baseUrl = 'https://api.xendit.co';
  static const String _secretKey = 'xnd_development_GLxc5Y02G2w5Sh2KjMVUUDKRcrHao7tgPNYAoE9TkgIPlZuKtczqjk9ZNIV';

  static Future<Map<String, dynamic>> createInvoice({
    required double amount,
    required String description,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      print('📝 Creating Xendit invoice...');
      print('Amount: ₱$amount');
      print('Customer: $customerName');

      // Create basic auth header
      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';

      // Prepare request body
      Map<String, dynamic> requestBody = {
        'external_id': 'invoice_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'description': description,
        'currency': 'PHP',
        'payer_email': customerEmail,
        'customer': {
          'given_names': customerName,
          'email': customerEmail,
          'mobile_number': customerPhone,
        },
        'customer_notification_preference': {
          'invoice_paid': ['email', 'whatsapp']
        },
        'success_redirect_url': 'https://your-app.com/payment/success',
        'failure_redirect_url': 'https://your-app.com/payment/failure',
        'invoice_duration': 86400, // 24 hours
      };

      // Make API request
      final response = await http.post(
        Uri.parse('$_baseUrl/v2/invoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Parse error message
        Map<String, dynamic> errorResponse = jsonDecode(response.body);
        String errorMessage = errorResponse['message'] ?? 'Unknown error';
        throw Exception('Xendit Error: $errorMessage');
      }
    } catch (e) {
      print('❌ Xendit Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getInvoice(String invoiceId) async {
    try {
      print('📝 Getting invoice status: $invoiceId');

      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';

      final response = await http.get(
        Uri.parse('$_baseUrl/v2/invoices/$invoiceId'),
        headers: {
          'Authorization': basicAuth,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get invoice status');
      }
    } catch (e) {
      print('❌ Error getting invoice: $e');
      rethrow;
    }
  }
}

// --- PAYMENT PAGE (UPDATED WITH userId) ---
class PaymentPage extends StatefulWidget {
  final String invoiceUrl;
  final String invoiceId;
  final String orderId;
  final double amount;
  final String userId; // ADD THIS

  const PaymentPage({
    super.key,
    required this.invoiceUrl,
    required this.invoiceId,
    required this.orderId,
    required this.amount,
    required this.userId, // ADD THIS
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Timer? _statusTimer;
  bool _isPaid = false;
  bool _isLoading = true;
  String? _errorMessage;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 30;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      _launchPaymentUrl();
      _startPolling();
    }
  }

  Future<void> _launchPaymentUrl() async {
    try {
      final Uri url = Uri.parse(widget.invoiceUrl);
      print('🔗 Launching payment URL: $url');

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
        print('✅ Payment page launched successfully');
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('❌ Error launching payment URL: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not open payment page. Please try again.';
        });
      }
    }
  }

  void _startPolling() {
    print('🔄 Starting payment status polling...');
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_pollingAttempts >= _maxPollingAttempts) {
        print('⏰ Polling timeout reached');
        timer.cancel();
        if (mounted) {
          setState(() {
            _errorMessage = 'Payment verification timeout. Please check your order status in Profile.';
          });
        }
        return;
      }

      _pollingAttempts++;
      print('🔄 Polling attempt #$_pollingAttempts');

      try {
        final invoice = await XenditService.getInvoice(widget.invoiceId);
        final status = invoice['status'];
        print('📊 Invoice status: $status');

        if (status == 'PAID' || status == 'SETTLED') {
          print('✅ Payment successful!');
          timer.cancel();

          if (mounted) {
            setState(() => _isPaid = true);

            // Update order status in Hive
            await _updateOrderStatus('Paid');

            // Wait 2 seconds then navigate to tracking
            await Future.delayed(const Duration(seconds: 2));

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(
                  builder: (_) => OrderTrackingPage(
                    orderId: widget.orderId,
                    userId: widget.userId, // USE THE USER ID HERE
                    onBackToHome: () => Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ),
                    (route) => false,
              );
            }
          }
        } else if (status == 'EXPIRED') {
          print('❌ Invoice expired');
          timer.cancel();
          if (mounted) {
            setState(() {
              _errorMessage = 'Payment session expired. Please try again.';
            });
          }
        }
      } catch (e) {
        print('❌ Polling error: $e');
        // Don't stop polling on error, just continue
      }
    });
  }

  Future<void> _updateOrderStatus(String status) async {
    try {
      final ordersBox = Hive.box('orders');
      final order = ordersBox.get(widget.orderId);
      if (order != null) {
        order['status'] = status;
        await ordersBox.put(widget.orderId, order);
        print('✅ Order status updated to: $status');
      }
    } catch (e) {
      print('❌ Error updating order status: $e');
    }
  }

  void _retryPayment() {
    setState(() {
      _errorMessage = null;
      _pollingAttempts = 0;
      _isLoading = true;
    });
    _initializePayment();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Payment Processing'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Cancel Payment'),
                content: const Text('Are you sure you want to cancel? Your order will not be processed.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Continue Payment'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text('Yes, Cancel'),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to checkout
                    },
                  ),
                ],
              ),
            );
          },
          child: const Icon(CupertinoIcons.xmark),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const CupertinoActivityIndicator(radius: 20),
                  const SizedBox(height: 24),
                  const Text(
                    'Preparing payment...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: CupertinoColors.systemRed,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Payment Error',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CupertinoColors.systemGrey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CupertinoButton(
                              onPressed: _retryPayment,
                              child: const Text('Try Again'),
                            ),
                            const SizedBox(width: 12),
                            CupertinoButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (!_isPaid) ...[
                  const CupertinoActivityIndicator(radius: 20),
                  const SizedBox(height: 24),
                  const Text(
                    'Waiting for payment...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total Amount: ₱${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.activeGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please complete the payment in the browser.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.creditcard, size: 16),
                            SizedBox(width: 8),
                            Text('Credit/Debit Card'),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.money_dollar, size: 16),
                            SizedBox(width: 8),
                            Text('GCash / PayMaya'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton(
                    onPressed: _launchPaymentUrl,
                    child: const Text('Open Payment Page Again'),
                  ),
                ] else ...[
                  const Icon(
                    CupertinoIcons.check_mark,
                    color: CupertinoColors.activeGreen,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount Paid: ₱${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.activeGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Redirecting to order tracking...',
                    style: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  const SizedBox(height: 20),
                  const CupertinoActivityIndicator(radius: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- CHECKOUT PAGE ---
class CheckoutPage extends StatefulWidget {
  final List<FoodItem> cart;
  final String userId;
  final VoidCallback onOrderPlaced;
  const CheckoutPage({super.key, required this.cart, required this.userId, required this.onOrderPlaced});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isProcessing = false;
  String _deliveryAddress = 'Getting your location...';
  LatLng? _deliveryLocation; // Point B - User's location
  bool _isGettingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Please enable location services';
          _isGettingLocation = false;
        });
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission required';
            _isGettingLocation = false;
          });
          return;
        }
      }

      // Get current position (Point B)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Location in Pampanga';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = '${place.locality ?? 'Pampanga'}, ${place.administrativeArea ?? ''}';
      }

      setState(() {
        _deliveryLocation = LatLng(position.latitude, position.longitude);
        _deliveryAddress = address;
        _isGettingLocation = false;
      });

    } catch (e) {
      setState(() {
        _locationError = 'Error getting location';
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (_deliveryLocation == null) {
      _showErrorDialog('Location Error', 'Unable to get your location');
      return;
    }

    setState(() => _isProcessing = true);

    final subtotal = widget.cart.fold(0.0, (sum, i) => sum + i.price);
    final total = subtotal + 49.0;
    final usersBox = Hive.box('users');
    final user = usersBox.get(widget.userId);

    try {
      // Show loading dialog
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 15),
              SizedBox(height: 16),
              Text('Creating your invoice...'),
            ],
          ),
        ),
      );

      // Create order with delivery location (Point B) and SM Pampanga (Point A)
      final orderId = 'QB-${DateTime.now().millisecondsSinceEpoch}';
      final ordersBox = Hive.box('orders');

      // Get restaurant info from first item
      final restaurantId = widget.cart.isNotEmpty ? widget.cart.first.restaurantId : 'r1';
      final restaurantNames = {'r1': 'Burger House', 'r2': 'Pizza Paradise', 'r3': 'Sushi Master'};

      final orderData = {
        'id': orderId,
        'userId': widget.userId,
        'items': widget.cart.map((item) => ({
          'id': item.id,
          'name': item.name,
          'price': item.price,
        })).toList(),
        'subtotal': subtotal,
        'deliveryFee': 49.0,
        'total': total,
        'status': 'Pending Payment',
        'paymentMethod': 'Xendit',
        'deliveryAddress': _deliveryAddress,
        'deliveryLocation': { // Point B - User's location
          'lat': _deliveryLocation!.latitude,
          'lng': _deliveryLocation!.longitude,
        },
        'restaurantId': restaurantId,
        'restaurantName': 'SM Pampanga - ${restaurantNames[restaurantId] ?? 'Restaurant'}',
        'restaurantLocation': { // Point A - SM Pampanga
          'lat': LocationConstants.smPampanga.latitude,
          'lng': LocationConstants.smPampanga.longitude,
        },
        'orderTime': DateTime.now().toIso8601String(),
      };

      await ordersBox.put(orderId, orderData);

      // Create Xendit invoice
      final invoice = await XenditService.createInvoice(
        amount: total,
        description: 'QuickBite Order #${orderId.substring(0, 8)}',
        customerName: user['name'] ?? 'Customer',
        customerEmail: user['email'] ?? 'customer@email.com',
        customerPhone: user['phone'] ?? '09123456789',
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      widget.onOrderPlaced();

      // Navigate to payment page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentPage(
              invoiceUrl: invoice['invoice_url'],
              invoiceId: invoice['id'],
              orderId: orderId,
              amount: total,
              userId: widget.userId, // PASS THE USER ID HERE
            ),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }

      _showErrorDialog('Payment Error', e.toString());
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cart.fold(0.0, (sum, i) => sum + i.price);
    final total = subtotal + 49.0;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Checkout'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Restaurant Info (Point A - SM Pampanga)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(CupertinoIcons.bag_fill, color: CupertinoColors.systemOrange),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('From:', style: TextStyle(color: CupertinoColors.systemGrey)),
                                Text('SM Pampanga', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Delivery Location (Point B - User's location)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(CupertinoIcons.location_fill, color: CupertinoColors.activeGreen),
                              SizedBox(width: 8),
                              Text('To:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isGettingLocation)
                            const Row(
                              children: [
                                CupertinoActivityIndicator(radius: 8),
                                SizedBox(width: 12),
                                Text('Getting your location...'),
                              ],
                            )
                          else if (_locationError != null)
                            Text(_locationError!, style: const TextStyle(color: CupertinoColors.destructiveRed))
                          else
                            Text(_deliveryAddress),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ...widget.cart.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.name)),
                                Text('₱${item.price.toStringAsFixed(2)}'),
                              ],
                            ),
                          )),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Fee'),
                              Expanded(child: Container()), // Add this to push the text right
                              const Text('₱49.00'),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.activeGreen),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Checkout Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                border: Border(
                  top: BorderSide(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: (_isProcessing || _isGettingLocation || _deliveryLocation == null)
                        ? null
                        : _processPayment,
                    child: _isProcessing
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : Text("Pay ₱${total.toStringAsFixed(2)} with Xendit"),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- FIXED ORDER TRACKING PAGE WITH PROPER NAVIGATION ---
class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  final String userId; // Add userId parameter
  final VoidCallback onBackToHome;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
    required this.userId, // Add this
    required this.onBackToHome
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late MapController _mapController;
  Timer? _updateTimer;
  Timer? _statusTimer;

  // Order data
  Map<String, dynamic>? _orderData;
  LatLng? _restaurantLocation; // Point A - SM Pampanga
  LatLng? _deliveryLocation;   // Point B - User's location

  // Route data
  OSMRoute? _route;
  List<LatLng> _polyline = [];

  // Tracking simulation
  double _progress = 0.0;
  String _status = "Order Confirmed";
  int _elapsedSeconds = 0;
  bool _isDelivered = false;
  bool _isLoading = true;
  LatLng? _currentRiderPosition;
  String? _errorMessage;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadOrderData();

    // Status update after 1 minute
    _statusTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_isDelivered && _status == "Order Confirmed") {
        setState(() => _status = "Rider on the way");
      }
    });
  }

  Future<void> _loadOrderData() async {
    try {
      final ordersBox = Hive.box('orders');
      final order = ordersBox.get(widget.orderId);

      if (order == null) {
        setState(() {
          _errorMessage = 'Order not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _orderData = Map<String, dynamic>.from(order);

        // Set Point A: SM Pampanga (restaurant)
        if (order['restaurantLocation'] != null) {
          _restaurantLocation = LatLng(
            order['restaurantLocation']['lat'],
            order['restaurantLocation']['lng'],
          );
        } else {
          _restaurantLocation = LocationConstants.smPampanga;
        }

        // Set Point B: User's pinned/delivery location
        if (order['deliveryLocation'] != null) {
          _deliveryLocation = LatLng(
            order['deliveryLocation']['lat'],
            order['deliveryLocation']['lng'],
          );
        }
      });

      // Get OSM route between SM Pampanga and delivery location
      await _getOSMRoute();

      // Center map to show both locations (only if map is ready)
      if (_mapReady) {
        _centerMap();
      }

      // Start tracking simulation
      _startTrackingSimulation();

    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading order: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getOSMRoute() async {
    if (_restaurantLocation == null || _deliveryLocation == null) return;

    setState(() => _isLoading = true);

    try {
      final route = await OSRMRoutingService.getRoute(
        _restaurantLocation!,
        _deliveryLocation!,
      );

      setState(() {
        _route = route;
        _polyline = route?.polyline ?? [];
        _isLoading = false;
      });

      print('✅ Route found: ${OSRMRoutingService.formatDistance(route!.distance)}');

    } catch (e) {
      print('❌ Error getting route: $e');
      setState(() {
        _polyline = [_restaurantLocation!, _deliveryLocation!];
        _isLoading = false;
      });
    }
  }

  void _centerMap() {
    if (_restaurantLocation == null || _deliveryLocation == null || !_mapReady) return;

    try {
      // Calculate center point between SM Pampanga and delivery location
      final centerLat = (_restaurantLocation!.latitude + _deliveryLocation!.latitude) / 2;
      final centerLng = (_restaurantLocation!.longitude + _deliveryLocation!.longitude) / 2;

      // Calculate appropriate zoom based on distance
      final distance = OSRMRoutingService._calculateDistance(
          _restaurantLocation!,
          _deliveryLocation!
      );

      double zoomLevel = 11.0;
      if (distance > 50000) zoomLevel = 9.0;      // >50km
      else if (distance > 20000) zoomLevel = 10.0; // >20km
      else if (distance > 10000) zoomLevel = 11.0; // >10km
      else if (distance > 5000) zoomLevel = 12.0;  // >5km
      else zoomLevel = 13.0;                        // <5km

      _mapController.move(LatLng(centerLat, centerLng), zoomLevel);
    } catch (e) {
      print('Error centering map: $e');
    }
  }

  void _startTrackingSimulation() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _isDelivered) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsedSeconds += 2;

        if (_progress < 1.0) {
          _progress += 0.01; // Slower progress for longer routes

          // Update status based on progress
          if (_progress >= 1.0) {
            _status = "Delivered";
            _isDelivered = true;
            timer.cancel();
            _statusTimer?.cancel();

            // Show delivery complete message
            _showDeliveryCompleteDialog();
          } else if (_progress >= 0.7 && _elapsedSeconds > 60) {
            _status = "Nearby - Arriving soon";
          } else if (_progress >= 0.4 && _elapsedSeconds > 60) {
            _status = "On the way";
          } else if (_progress >= 0.2 && _elapsedSeconds > 60) {
            _status = "Order picked up";
          }

          // Calculate current rider position along polyline
          if (_polyline.isNotEmpty) {
            _currentRiderPosition = _getPositionAlongPolyline(_progress);
          }
        }
      });
    });
  }

  LatLng _getPositionAlongPolyline(double progress) {
    if (_polyline.isEmpty) return _restaurantLocation!;
    if (progress >= 1.0) return _polyline.last;

    final totalLength = _polyline.length - 1;
    final targetIndex = progress * totalLength;
    final segmentIndex = targetIndex.floor();
    final segmentProgress = targetIndex - segmentIndex;

    if (segmentIndex >= totalLength) return _polyline.last;

    final start = _polyline[segmentIndex];
    final end = _polyline[segmentIndex + 1];

    return LatLng(
      start.latitude + (end.latitude - start.latitude) * segmentProgress,
      start.longitude + (end.longitude - start.longitude) * segmentProgress,
    );
  }

  void _showDeliveryCompleteDialog() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return CupertinoAlertDialog(
              title: const Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: CupertinoColors.activeGreen,
                size: 60,
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 16),
                  Text(
                    'Order Delivered!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Thank you for ordering with QuickBite.'),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Back to Home', style: TextStyle(color: CupertinoColors.activeGreen)),
                  onPressed: () {
                    // Close the dialog first
                    Navigator.of(dialogContext).pop();

                    // Then navigate back to HomePage
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        CupertinoPageRoute(
                          builder: (_) => HomePage(userId: widget.userId),
                        ),
                            (route) => false, // This removes all previous routes
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _statusTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator(radius: 15)),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Track Order #${widget.orderId.substring(0, 8)}'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.home, color: CupertinoColors.activeGreen),
          onPressed: () {
            // Direct navigation to home when home button is pressed
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(
                builder: (_) => HomePage(userId: widget.userId),
              ),
                  (route) => false,
            );
          },
        ),
      ),
      child: Column(
        children: [
          // Map View
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _restaurantLocation ?? LocationConstants.smPampanga,
                    zoom: 11.0,
                    onMapReady: () {
                      setState(() {
                        _mapReady = true;
                      });
                      _centerMap();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.quickbite',
                    ),

                    // OSM Route Polyline
                    if (_polyline.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _polyline,
                            color: CupertinoColors.activeGreen,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),

                    // Markers
                    MarkerLayer(
                      markers: [
                        // SM Pampanga (Point A - Restaurant)
                        if (_restaurantLocation != null)
                          Marker(
                            point: _restaurantLocation!,
                            width: 80,
                            height: 80,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemOrange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CupertinoColors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.bag_fill,
                                    color: CupertinoColors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'SM Pampanga',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Delivery Location (Point B - User's location)
                        if (_deliveryLocation != null)
                          Marker(
                            point: _deliveryLocation!,
                            width: 80,
                            height: 80,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CupertinoColors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.house_fill,
                                    color: CupertinoColors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Your Location',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Rider Position
                        if (_currentRiderPosition != null)
                          Marker(
                            point: _currentRiderPosition!,
                            width: 60,
                            height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.activeGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CupertinoColors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.delivery_dining,
                                    color: CupertinoColors.white,
                                    size: 20,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Rider',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Status Overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getStatusIcon(),
                                color: CupertinoColors.activeGreen,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _status,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_route != null && _progress < 1.0)
                                    Text(
                                      '${OSRMRoutingService.formatDistance(_route!.distance * (1 - _progress))} remaining',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _progress,
                          color: CupertinoColors.activeGreen,
                          backgroundColor: CupertinoColors.systemGrey6,
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                ),

                // Route Info Overlay
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(CupertinoIcons.bag_fill, color: CupertinoColors.systemOrange, size: 16),
                              const SizedBox(height: 4),
                              const Text(
                                'SM Pampanga',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: const Icon(CupertinoIcons.arrow_right, color: CupertinoColors.activeGreen),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(CupertinoIcons.house_fill, color: CupertinoColors.systemBlue, size: 16),
                              const SizedBox(height: 4),
                              const Text(
                                'Your Location',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Delivery Details Panel
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Route Summary
                    if (_route != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.map, size: 16, color: CupertinoColors.activeGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Total distance: ${OSRMRoutingService.formatDistance(_route!.distance)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              'ETA: ${OSRMRoutingService.formatDuration(_route!.duration * (1 - _progress))}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Delivery Steps
                    _buildDeliveryStep(
                      icon: CupertinoIcons.cart_fill,
                      title: 'Order Confirmed',
                      time: 'Just now',
                      isCompleted: true,
                    ),
                    _buildDeliveryStep(
                      icon: CupertinoIcons.clock_fill,
                      title: 'Preparing Order',
                      time: _progress >= 0.2 ? 'Completed' : 'In progress',
                      isCompleted: _progress >= 0.2,
                    ),
                    _buildDeliveryStep(
                      icon: Icons.delivery_dining,
                      title: 'Picked Up',
                      time: _progress >= 0.4 ? 'Completed' : 'Pending',
                      isCompleted: _progress >= 0.4,
                    ),
                    _buildDeliveryStep(
                      icon: CupertinoIcons.house_fill,
                      title: 'On The Way',
                      time: _progress >= 0.6 ? 'In progress' : 'Pending',
                      isCompleted: _progress >= 0.6,
                    ),
                    _buildDeliveryStep(
                      icon: CupertinoIcons.checkmark_seal_fill,
                      title: 'Delivered',
                      time: _progress >= 1.0 ? 'Completed' : 'Pending',
                      isCompleted: _progress >= 1.0,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Error'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.home),
          onPressed: () {
            // Direct navigation to home on error
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(
                builder: (_) => HomePage(userId: widget.userId),
              ),
                  (route) => false,
            );
          },
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 60,
                color: CupertinoColors.destructiveRed,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    CupertinoPageRoute(
                      builder: (_) => HomePage(userId: widget.userId),
                    ),
                        (route) => false,
                  );
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case 'Delivered':
        return CupertinoIcons.checkmark_alt_circle_fill;
      case 'Nearby - Arriving soon':
        return CupertinoIcons.location_fill;
      case 'On the way':
        return Icons.delivery_dining;
      case 'Order picked up':
        return CupertinoIcons.bag_fill;
      default:
        return CupertinoIcons.clock_fill;
    }
  }

  Widget _buildDeliveryStep({
    required IconData icon,
    required String title,
    required String time,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? CupertinoColors.activeGreen.withValues(alpha: 0.1)
                      : CupertinoColors.systemGrey6,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isCompleted
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemGrey,
                  size: 16,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: isCompleted
                      ? CupertinoColors.activeGreen.withValues(alpha: 0.3)
                      : CupertinoColors.systemGrey6,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? CupertinoColors.black : CupertinoColors.systemGrey,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CUPERTINO LIST TILE ---
class CupertinoListTile extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final VoidCallback? onTap;
  const CupertinoListTile({super.key, required this.leading, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: CupertinoColors.white,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(child: title),
          ],
        ),
      ),
    );
  }
}
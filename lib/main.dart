import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, LinearProgressIndicator, Icons, CircleAvatar, Material, Colors;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        'name': 'Burger House',
        'imageUrl': 'https://images.unsplash.com/photo-1571091718767-18b5b1457add',
        'rating': 4.5,
        'deliveryTime': 25,
        'deliveryFee': 49.0,
        'minOrder': 100.0,
        'isOpen': true,
        'latitude': 14.5995,
        'longitude': 120.9842,
        'cuisine': 'American',
        'address': '123 Main St, Manila',
      },
      {
        'id': 'r2',
        'name': 'Pizza Paradise',
        'imageUrl': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38',
        'rating': 4.8,
        'deliveryTime': 30,
        'deliveryFee': 59.0,
        'minOrder': 200.0,
        'isOpen': true,
        'latitude': 14.6010,
        'longitude': 120.9880,
        'cuisine': 'Italian',
        'address': '456 Oak Ave, Manila',
      },
      {
        'id': 'r3',
        'name': 'Sushi Master',
        'imageUrl': 'https://images.unsplash.com/photo-1553621042-f6e147245754',
        'rating': 4.7,
        'deliveryTime': 35,
        'deliveryFee': 69.0,
        'minOrder': 300.0,
        'isOpen': true,
        'latitude': 14.5970,
        'longitude': 120.9860,
        'cuisine': 'Japanese',
        'address': '789 Pine St, Manila',
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
        middle: const Text('QuickBite', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Popular Restaurants', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
    final response = await http.post(
      Uri.parse('$_baseUrl/v2/invoices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
      },
      body: jsonEncode({
        'external_id': 'invoice_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'description': description,
        'customer': {'given_names': customerName, 'email': customerEmail, 'mobile_number': customerPhone},
        'success_redirect_url': 'https://your-app.com/success',
        'failure_redirect_url': 'https://your-app.com/failure',
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create invoice');
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
  final String _deliveryAddress = '123 Main St, Manila';

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    final total = widget.cart.fold(0.0, (sum, i) => sum + i.price) + 49.0;
    final usersBox = Hive.box('users');
    final user = usersBox.get(widget.userId);

    try {
      final invoice = await XenditService.createInvoice(
        amount: total,
        description: 'QuickBite Order - ${widget.cart.length} items',
        customerName: user['name'],
        customerEmail: user['email'],
        customerPhone: user['phone'],
      );

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Confirm Payment'),
            content: Text('Total: ₱${total.toStringAsFixed(2)}\nProceed to payment gateway?'),
            actions: [
              CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isProcessing = false);
                  }
              ),
              CupertinoDialogAction(
                child: const Text('Pay Now'),
                onPressed: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(invoice['invoice_url']);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                    await Future.delayed(const Duration(seconds: 2));
                    _createOrder(total);
                  }
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('Payment Error', e.toString());
      setState(() => _isProcessing = false);
    }
  }

  void _createOrder(double total) async {
    final orderId = 'QB-${DateTime.now().millisecondsSinceEpoch}';
    final ordersBox = Hive.box('orders');

    await ordersBox.put(orderId, {
      'id': orderId,
      'userId': widget.userId,
      'items': widget.cart.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
      }).toList(),
      'total': total,
      'status': 'Paid',
      'paymentMethod': 'Xendit',
      'deliveryAddress': _deliveryAddress,
      'orderTime': DateTime.now().toIso8601String(),
    });

    widget.onOrderPlaced();

    if (mounted) {
      Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
              builder: (_) => OrderTrackingPage(
                  orderId: orderId,
                  onBackToHome: () => Navigator.popUntil(context, (r) => r.isFirst)
              )
          )
      );
    }
  }

  void _showError(String title, String message) {
    showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _isProcessing = false);
                  }
              )
            ]
        )
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
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Delivery Address
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
                            Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_deliveryAddress),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Items
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
                        const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ...widget.cart.map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(i.name)),
                              Text('₱${i.price.toStringAsFixed(2)}'),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price Breakdown
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal'),
                            Text('₱${subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Fee'),
                            const Text('₱49.00'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('₱${total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: CupertinoColors.activeGreen)
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Checkout Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text(
                        "Cancel Order",
                        style: TextStyle(
                          color: CupertinoColors.destructiveRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _isProcessing ? null : _processPayment,
                      child: _isProcessing
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : Text("Pay ₱${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ORDER TRACKING PAGE ---
class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  final VoidCallback onBackToHome;
  const OrderTrackingPage({super.key, required this.orderId, required this.onBackToHome});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  double _progress = 0.2;
  String _status = "Order confirmed";

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_progress < 1.0) { _progress += 0.2; }
        if (_progress >= 1.0) { _status = "Delivered"; t.cancel(); }
        else if (_progress >= 0.8) { _status = "On the way"; }
        else if (_progress >= 0.4) { _status = "Preparing"; }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Tracking')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill, size: 80, color: CupertinoColors.activeGreen),
              const SizedBox(height: 24),
              Text(_status, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress, color: CupertinoColors.activeGreen, backgroundColor: CupertinoColors.systemGrey6),
              const SizedBox(height: 48),
              SizedBox(width: double.infinity, child: CupertinoButton.filled(onPressed: widget.onBackToHome, borderRadius: BorderRadius.circular(12), child: const Text('Back to Home'))),
            ],
          ),
        ),
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
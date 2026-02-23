import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('transactions');
  await Hive.openBox('orders');
  await Hive.openBox('users');
  runApp(QuickBiteApp());
}

class QuickBiteApp extends StatelessWidget {
  QuickBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeGreen,
        barBackgroundColor: CupertinoColors.white,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showDialog('Error', 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    final usersBox = Hive.box('users');
    bool userFound = false;

    for (var key in usersBox.keys) {
      final userData = usersBox.get(key);
      if (userData['email'] == _emailController.text &&
          userData['password'] == _passwordController.text) {
        userFound = true;
        break;
      }
    }

    setState(() => _isLoading = false);

    if (userFound && mounted) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => HomePage()),
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
          ),
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
              CupertinoColors.systemGreen.withOpacity(0.1),
              CupertinoColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    CupertinoIcons.cart_fill,
                    size: 60,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.darkBackgroundGray,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Sign in to continue ordering',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 48),

                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGrey5,
                      width: 1,
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _emailController,
                    placeholder: 'Email',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.mail, color: CupertinoColors.activeGreen),
                    ),
                    padding: const EdgeInsets.all(16),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGrey5,
                      width: 1,
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.lock_fill, color: CupertinoColors.activeGreen),
                    ),
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(
                        _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                        color: CupertinoColors.activeGreen,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    padding: const EdgeInsets.all(16),
                    obscureText: _obscurePassword,
                  ),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.activeGreen,
                      ),
                    ),
                    onPressed: () {
                      _showDialog('Reset Password', 'Please contact support to reset your password.');
                    },
                  ),
                ),

                const SizedBox(height: 32),

                CupertinoButton.filled(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: CupertinoColors.secondaryLabel),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: CupertinoColors.activeGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => SignUpPage()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class SignUpPage extends StatefulWidget {
  SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showDialog('Error', 'Please fill in all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showDialog('Error', 'Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showDialog('Error', 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    final usersBox = Hive.box('users');

    bool emailExists = false;
    for (var key in usersBox.keys) {
      final userData = usersBox.get(key);
      if (userData['email'] == _emailController.text) {
        emailExists = true;
        break;
      }
    }

    if (emailExists) {
      setState(() => _isLoading = false);
      _showDialog('Error', 'Email already registered');
      return;
    }

    await usersBox.add({
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'password': _passwordController.text,
      'createdAt': DateTime.now().toIso8601String(),
    });

    setState(() => _isLoading = false);

    if (mounted) {
      _showSuccessDialog();
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
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success!'),
        content: const Text('Your account has been created successfully. Please login to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.systemGreen.withOpacity(0.05),
              CupertinoColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                const Text(
                  'Join QuickBite',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create an account to start ordering',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 32),

                _buildTextField(
                  controller: _nameController,
                  placeholder: 'Full Name',
                  icon: CupertinoIcons.person_fill,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _emailController,
                  placeholder: 'Email Address',
                  icon: CupertinoIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _phoneController,
                  placeholder: 'Phone Number',
                  icon: CupertinoIcons.phone_fill,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _passwordController,
                  placeholder: 'Password',
                  icon: CupertinoIcons.lock_fill,
                  obscureText: _obscurePassword,
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                      color: CupertinoColors.activeGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _confirmPasswordController,
                  placeholder: 'Confirm Password',
                  icon: CupertinoIcons.lock_fill,
                  obscureText: _obscureConfirmPassword,
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _obscureConfirmPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                      color: CupertinoColors.activeGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password Requirements:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• At least 6 characters long',
                        style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                CupertinoButton.filled(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: CupertinoColors.secondaryLabel),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: CupertinoColors.activeGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGrey5,
          width: 1,
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(icon, color: CupertinoColors.activeGreen, size: 20),
        ),
        suffix: suffix,
        padding: const EdgeInsets.all(16),
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class FoodItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final int prepTime;
  final double rating;

  FoodItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.prepTime,
    required this.rating,
  });
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<FoodItem> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<FoodItem> _foods = [
    FoodItem(
      id: '1',
      name: 'Classic Burger',
      price: 149.00,
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
      description: 'Juicy beef patty with fresh lettuce, tomatoes, and our special sauce',
      prepTime: 15,
      rating: 4.5,
    ),
    FoodItem(
      id: '2',
      name: 'Margherita Pizza',
      price: 299.00,
      imageUrl: 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca',
      description: 'Classic Italian pizza with fresh basil, mozzarella, and tomato sauce',
      prepTime: 20,
      rating: 4.8,
    ),
    FoodItem(
      id: '3',
      name: 'Sushi Platter',
      price: 449.00,
      imageUrl: 'https://images.unsplash.com/photo-1553621042-f6e147245754',
      description: 'Assorted fresh sushi rolls with wasabi and ginger',
      prepTime: 25,
      rating: 4.7,
    ),
    FoodItem(
      id: '4',
      name: 'Caesar Salad',
      price: 199.00,
      imageUrl: 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9',
      description: 'Fresh romaine lettuce with Caesar dressing, croutons, and parmesan',
      prepTime: 10,
      rating: 4.3,
    ),
  ];

  List<String> get categories {
    Set<String> cats = {'All'};
    for (var food in _foods) {
      cats.add(food.name.split(' ').last);
    }
    return cats.toList();
  }

  List<FoodItem> get filteredFoods {
    if (_selectedCategory == 'All') return _foods;
    return _foods.where((f) => f.name.contains(_selectedCategory)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('QuickBite'),
        trailing: GestureDetector(
          onTap: _navigateToCart,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(CupertinoIcons.cart),
              if (_cart.isNotEmpty)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.activeGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_cart.length}',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Search for food...',
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CupertinoButton(
                          onPressed: () => setState(() => _selectedCategory = category),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: isSelected
                              ? CupertinoColors.activeGreen
                              : CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(20),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? CupertinoColors.white
                                  : CupertinoColors.black,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final food = filteredFoods[index];
                    return _FoodCard(
                      food: food,
                      onAddToCart: () => _addToCart(food),
                    );
                  },
                  childCount: filteredFoods.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(FoodItem food) {
    setState(() => _cart.add(food));
    _showSnackBar('${food.name} added to cart');
  }

  void _showSnackBar(String message) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPopupSurface(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: CupertinoColors.black.withOpacity(0.8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.check_mark_circled, color: CupertinoColors.white),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(color: CupertinoColors.white),
              ),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
  }

  void _navigateToCart() {
    if (_cart.isNotEmpty) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => CheckoutPage(cart: _cart)),
      );
    } else {
      _showSnackBar('Your cart is empty');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _FoodCard extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onAddToCart;

  const _FoodCard({required this.food, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              food.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: CupertinoColors.systemGrey5,
                  child: const Icon(CupertinoIcons.photo, size: 40),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.star_fill, size: 12, color: CupertinoColors.activeGreen),
                          const SizedBox(width: 4),
                          Text(
                            food.rating.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          const Icon(CupertinoIcons.clock, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${food.prepTime}min',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${food.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: CupertinoColors.activeGreen,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: onAddToCart,
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: CupertinoColors.activeGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.add,
                            size: 16,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ],
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

class CheckoutPage extends StatelessWidget {
  final List<FoodItem> cart;

  const CheckoutPage({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    double subtotal = 0;
    for (var item in cart) {
      subtotal += item.price;
    }
    const deliveryFee = 50.0;
    final tax = subtotal * 0.12;
    final total = subtotal + deliveryFee + tax;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Checkout'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Your Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...cart.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: CupertinoColors.systemGrey5,
                                child: const Icon(CupertinoIcons.photo),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '₱${item.price.toStringAsFixed(0)}',
                                style: const TextStyle(color: CupertinoColors.activeGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),

                  Container(
                    height: 1,
                    color: CupertinoColors.systemGrey5,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                  ),

                  _buildPriceRow('Subtotal', subtotal),
                  _buildPriceRow('Delivery Fee', deliveryFee),
                  _buildPriceRow('Tax (12%)', tax),
                  Container(
                    height: 1,
                    color: CupertinoColors.systemGrey5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  _buildPriceRow('Total', total, isTotal: true),

                  const SizedBox(height: 24),

                  const Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.location_solid, color: CupertinoColors.activeGreen),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Home',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '123 Main Street, Makati City',
                                style: TextStyle(color: CupertinoColors.secondaryLabel),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: CupertinoButton.filled(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => PaymentPage(amount: total),
                      ),
                    );
                  },
                  child: Text('Place Order • ₱${total.toStringAsFixed(0)}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? CupertinoColors.black : CupertinoColors.secondaryLabel,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? CupertinoColors.activeGreen : null,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  final double amount;

  const PaymentPage({super.key, required this.amount});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            if (request.url.contains('success') || request.url.contains('mock')) {
              _handlePaymentSuccess();
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://checkout.xendit.co/web/mock'));
  }

  void _handlePaymentSuccess() async {
    final box = Hive.box('transactions');
    await box.add({
      'amount': widget.amount,
      'date': DateTime.now().toIso8601String(),
      'reference': 'TRX-${DateTime.now().millisecondsSinceEpoch}',
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => OrderTrackingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Payment'),
        trailing: _isLoading
            ? const CupertinoActivityIndicator()
            : null,
      ),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CupertinoActivityIndicator()),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: CupertinoButton(
              color: CupertinoColors.white,
              child: const Text('Simulate Payment Success'),
              onPressed: _handlePaymentSuccess,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderTrackingPage extends StatefulWidget {
  OrderTrackingPage({super.key});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  String _orderStatus = 'Order Confirmed';
  LatLng _riderPosition = const LatLng(14.5995, 120.9842);
  LatLng? _destinationPosition;
  List<LatLng> _route = [];
  Timer? _statusTimer;
  Timer? _riderTimer;
  int _currentRouteIndex = 0;

  @override
  void initState() {
    super.initState();
    _startStatusTimer();
  }

  void _startStatusTimer() {
    _statusTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _orderStatus = 'Delivery is on the way';
        });
      }
    });
  }

  List<LatLng> calculateAStarRoute(LatLng start, LatLng end) {
    List<LatLng> path = [];

    double distance = _calculateDistance(start, end);
    int steps = (distance * 10).ceil().clamp(10, 50);

    for (int i = 0; i <= steps; i++) {
      double t = i / steps;

      double lat = start.latitude + (end.latitude - start.latitude) * t;
      double lng = start.longitude + (end.longitude - start.longitude) * t;

      if (i > 0 && i < steps) {
        lat += sin(t * pi) * 0.002;
        lng += cos(t * pi) * 0.002;
      }

      path.add(LatLng(lat, lng));
    }

    return path;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    double latDiff = point1.latitude - point2.latitude;
    double lngDiff = point1.longitude - point2.longitude;
    return sqrt(latDiff * latDiff + lngDiff * lngDiff) * 111;
  }

  void _startRiderSimulation() {
    if (_destinationPosition == null || _route.isEmpty) return;

    _riderTimer?.cancel();
    _currentRouteIndex = 0;

    _riderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRouteIndex >= _route.length) {
        timer.cancel();
        _showDeliveryCompleteDialog();
        return;
      }

      setState(() {
        _riderPosition = _route[_currentRouteIndex];
        _currentRouteIndex++;
      });
    });
  }

  void _showDeliveryCompleteDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delivery Complete!'),
        content: const Text('Your order has been delivered. Enjoy your meal!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _riderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_orderStatus),
        trailing: _orderStatus == 'Order Confirmed'
            ? const Icon(CupertinoIcons.clock, color: CupertinoColors.activeGreen)
            : const Icon(CupertinoIcons.car_detailed, color: CupertinoColors.activeGreen),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: CupertinoColors.white,
            child: Row(
              children: [
                _buildTimelineItem('Order\nConfirmed', 0, isCompleted: true),
                _buildTimelineLine(),
                _buildTimelineItem('Preparing', 1,
                    isCompleted: _orderStatus != 'Order Confirmed'),
                _buildTimelineLine(),
                _buildTimelineItem('On the Way', 2,
                    isCompleted: _orderStatus == 'Delivery is on the way'),
                _buildTimelineLine(),
                _buildTimelineItem('Delivered', 3),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _riderPosition,
                    initialZoom: 14,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _destinationPosition = point;
                        _route = calculateAStarRoute(_riderPosition, point);
                      });
                      _startRiderSimulation();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.quickbite',
                    ),

                    if (_destinationPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destinationPosition!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.destructiveRed.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.location_solid,
                                color: CupertinoColors.destructiveRed,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _riderPosition,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeGreen.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.car_detailed,
                              color: CupertinoColors.activeGreen,
                              size: 35,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_route.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route,
                            color: CupertinoColors.activeGreen,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                  ],
                ),

                if (_destinationPosition == null)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.hand_point_left, color: CupertinoColors.activeGreen),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap on the map to set your delivery location',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.person_fill, color: CupertinoColors.activeGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Rider',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                              Text(
                                _destinationPosition != null
                                    ? 'Rider is ${_calculateDistance(_riderPosition, _destinationPosition!).toStringAsFixed(1)} km away'
                                    : 'Waiting for location',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.chat_bubble_text_fill),
                          onPressed: () {
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Contact Rider'),
                                content: const Text('This is a demo. In a real app, you could message your rider here.'),
                                actions: [
                                  CupertinoDialogAction(
                                    child: const Text('OK'),
                                    onPressed: () => Navigator.pop(context),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, int index, {bool isCompleted = false}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? CupertinoColors.activeGreen : CupertinoColors.systemGrey5,
              border: Border.all(
                color: isCompleted ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(CupertinoIcons.check_mark, color: CupertinoColors.white, size: 20)
                  : Text(
                '${index + 1}',
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isCompleted ? CupertinoColors.black : CupertinoColors.secondaryLabel,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineLine() {
    return Container(
      width: 30,
      height: 2,
      color: CupertinoColors.systemGrey5,
    );
  }
}
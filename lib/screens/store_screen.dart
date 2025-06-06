import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/store_item.dart';
import '../services/store_service.dart';
import '../services/auth_service.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with TickerProviderStateMixin {
  final StoreService _storeService = StoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<StoreItem> _topUpItems = [];
  List<StoreItem> _powerUpItems = [];
  List<StoreItem> _filteredTopUpItems = [];
  List<StoreItem> _filteredPowerUpItems = [];
  String _searchQuery = '';

  // Animation controllers
  late AnimationController _slideAnimController;
  late AnimationController _fadeAnimController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStoreItems();
    _searchController.addListener(_onSearchChanged);
  }

  void _setupAnimations() {
    _slideAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimController,
            curve: Curves.easeOutBack,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeAnimController, curve: Curves.easeOut),
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredTopUpItems = _topUpItems.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.dolarPrice.toString().contains(query);
      }).toList();
      _filteredPowerUpItems = _powerUpItems.where((item) {
        return item.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadStoreItems() async {
    setState(() => _isLoading = true);
    try {
      print('memuat barang store...');

      // Initialize store service
      print('memuat layanan store...');
      await _storeService.init();

      // Get items
      print('mengambil barang top-up dan power-up...');
      final topUpItems = _storeService.getTopUpItems();
      final powerUpItems = _storeService.getPowerUpItems();

      print('barang top-up berhasil dimuat: ${topUpItems.length}');
      print('barang power-up berhasil dimuat: ${powerUpItems.length}');

      // If no items are loaded, try resetting the store
      if (topUpItems.isEmpty && powerUpItems.isEmpty) {
        print('tidak ada barang yang ditemukan, mereset store...');
        await _storeService.resetStore();

        // Try loading items again after reset
        print('memuat ulang barang setelah mereset...');
        final resetTopUpItems = _storeService.getTopUpItems();
        final resetPowerUpItems = _storeService.getPowerUpItems();

        print('setelah mereset - barang top-up: ${resetTopUpItems.length}');
        print('setelah mereset - barang power-up: ${resetPowerUpItems.length}');

        if (resetTopUpItems.isEmpty && resetPowerUpItems.isEmpty) {
          throw Exception(
            'barang store tidak dapat dimuat meskipun sudah mereset',
          );
        }

        setState(() {
          _topUpItems = resetTopUpItems;
          _powerUpItems = resetPowerUpItems;
        });
      } else {
        setState(() {
          _topUpItems = topUpItems;
          _powerUpItems = powerUpItems;
        });
      }

      print('barang store berhasil dimuat');
      print('barang top-up dalam state: ${_topUpItems.length}');
      print('barang power-up dalam state: ${_powerUpItems.length}');

      setState(() => _isLoading = false);

      // Start animations
      _fadeAnimController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _slideAnimController.forward();
    } catch (e, stackTrace) {
      print('error saat memuat barang store:');
      print('error: $e');
      print('trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(
          'gagal memuat barang store. silahkan coba lagi. jika masalah tetap terjadi, restart aplikasi.',
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Coba Lagi',
          textColor: Colors.white,
          onPressed: _loadStoreItems,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handlePurchase(
    Future<bool> Function() purchaseFunction,
    String itemName,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder<bool>(
        future: purchaseFunction(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.amber),
                    const SizedBox(height: 16),
                    Text(
                      'memproses pembelian...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            String errorMessage = snapshot.error.toString();
            // Remove 'Exception: ' prefix if it exists
            if (errorMessage.startsWith('Exception: ')) {
              errorMessage = errorMessage.substring(10);
            }

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pembelian Gagal',
                      style: GoogleFonts.poppins(
                        color: Colors.red[400],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: errorMessage
                    .split('\n')
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          line,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            );
          }

          final success = snapshot.data ?? false;
          if (!success) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Pembelian Gagal',
                    style: GoogleFonts.poppins(
                      color: Colors.red[400],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tidak dapat melakukan pembelian karena akan melebihi batas maksimum saldo:',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[900]?.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red[300]!.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Batas maksimum saldo adalah 10,000,000 Dolar',
                      style: GoogleFonts.poppins(
                        color: Colors.red[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            );
          }

          // Success case
          final navigator = Navigator.of(context);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              navigator.pop();
              setState(() {}); // Refresh UI
              _showSuccessSnackBar('$itemName berhasil dibeli!');
            }
          });

          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green[400],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Success!',
                  style: GoogleFonts.poppins(
                    color: Colors.green[400],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'pembelian berhasil.',
              style: GoogleFonts.poppins(color: Colors.grey[300]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopUpCard(StoreItem item, int index) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value.dy * 50 * (index + 1)),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green[600]!.withOpacity(0.8),
                    Colors.green[700]!.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handlePurchase(
                    () => _storeService.purchaseTopUp(item.id),
                    item.name,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.attach_money_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.dolarPrice.toStringAsFixed(0)} Dolar',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: FutureBuilder<String>(
                            future: _storeService.getLocalizedPrice(
                              item.dolarPrice,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                );
                              }
                              return Text(
                                snapshot.data ?? 'Harga tidak tersedia',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPowerUpCard(StoreItem item, int index) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    IconData icon;
    Color cardColor;
    switch (item.iconName) {
      case 'percent':
        icon = Icons.percent_rounded;
        cardColor = Colors.purple[600]!;
        break;
      case 'phone':
        icon = Icons.phone_rounded;
        cardColor = Colors.blue[600]!;
        break;
      case 'people':
        icon = Icons.people_rounded;
        cardColor = Colors.orange[600]!;
        break;
      default:
        icon = Icons.star_rounded;
        cardColor = Colors.amber[600]!;
    }

    int owned = 0;
    switch (item.id) {
      case 'power_up_fifty_fifty':
        owned = user.powerUpStats.fiftyFiftyUsed;
        break;
      case 'power_up_call_friend':
        owned = user.powerUpStats.callFriendUsed;
        break;
      case 'power_up_audience':
        owned = user.powerUpStats.audienceUsed;
        break;
    }

    final isMaxed = owned >= 10; // Maximum 10 power-ups per type

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value.dy * 50 * (index + 1)),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Opacity(
              opacity: isMaxed ? 0.6 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cardColor.withOpacity(0.8),
                      cardColor.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isMaxed
                        ? null
                        : () => _handlePurchase(
                            () => _storeService.purchasePowerUp(item.id),
                            item.name,
                          ),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(icon, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.name,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (!isMaxed)
                            Text(
                              '${item.dolarPrice.toStringAsFixed(0)} Dolar',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMaxed
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isMaxed
                                  ? 'PENGGUNAAN MAXIMUM'
                                  : 'Owned: $owned/10',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A), // Slate 900
            const Color(0xFF1E293B), // Slate 800
            const Color(0xFF334155), // Slate 700
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = _authService.currentUser;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.amber,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toko Pak Buset', // Translated
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ayo top up dolar agar saya cepat kaya raya',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (user != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Saldo', // Translated
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '\$${user.dolarBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Cari barang...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.amber),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _slideAnimController.dispose();
    _fadeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat store...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Toko Pak Buset',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.amber),
            onPressed: _loadStoreItems,
            tooltip: 'Refresh Store',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          RefreshIndicator(
            onRefresh: _loadStoreItems,
            color: Colors.amber,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  const SizedBox(height: 16),

                  if (_searchQuery.isNotEmpty &&
                      _filteredTopUpItems.isEmpty &&
                      _filteredPowerUpItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items found',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (_filteredTopUpItems.isNotEmpty || _searchQuery.isEmpty)
                      _buildSectionTitle(
                        '💰 Top Up Dolars',
                        subtitle: 'Tambahkan dolar ke akun Anda',
                      ),
                    const SizedBox(height: 16),
                    if (_filteredTopUpItems.isNotEmpty || _searchQuery.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: _searchQuery.isEmpty
                              ? _topUpItems.length
                              : _filteredTopUpItems.length,
                          itemBuilder: (context, index) => _buildTopUpCard(
                            _searchQuery.isEmpty
                                ? _topUpItems[index]
                                : _filteredTopUpItems[index],
                            index,
                          ),
                        ),
                      ),

                    if (_filteredPowerUpItems.isNotEmpty ||
                        _searchQuery.isEmpty) ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        '⚡ Power Up',
                        subtitle: 'Maksimal 10 barang per jenis',
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                          itemCount: _searchQuery.isEmpty
                              ? _powerUpItems.length
                              : _filteredPowerUpItems.length,
                          itemBuilder: (context, index) => _buildPowerUpCard(
                            _searchQuery.isEmpty
                                ? _powerUpItems[index]
                                : _filteredPowerUpItems[index],
                            index,
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

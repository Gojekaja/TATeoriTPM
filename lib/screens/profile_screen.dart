import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/currency_converter.dart';
import '../utils/localization_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? _user;
  final TextEditingController _usernameController = TextEditingController();
  File? _newProfilePic;
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _user = currentUser;
          _usernameController.text = _user!.username;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error memuat profil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isUsernameValid(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,10}$');
    return regex.hasMatch(username);
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _newProfilePic = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal memilih gambar: $e');
      }
    }
  }

  Widget _buildProfilePicture(
    String picturePath, {
    File? newPic,
    double radius = 50,
  }) {
    ImageProvider getImageProvider() {
      if (newPic != null) {
        return FileImage(newPic);
      }
      if (picturePath.startsWith('assets/')) {
        return AssetImage(picturePath);
      }
      return FileImage(File(picturePath));
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue[300]!.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(radius: radius, backgroundImage: getImageProvider()),
    );
  }

  void _showEditProfileDialog() {
    _newProfilePic = null;
    _usernameController.text = _user?.username ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue[300], size: 24),
              const SizedBox(width: 8),
              Text(
                "Edit Profile",
                style: GoogleFonts.inter(
                  color: Colors.blue[300],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await _pickImage();
                    setDialogState(() {});
                  },
                  child: Stack(
                    children: [
                      _buildProfilePicture(
                        _user!.profilePicPath,
                        newPic: _newProfilePic,
                        radius: 55,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue[300],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  maxLength: 10,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: GoogleFonts.inter(color: Colors.blue[300]),
                    hintText: 'Masukkan 3-10 karakter',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                    helperText: 'Huruf, angka, dan garis bawah hanya',
                    helperStyle: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue[300]!.withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue[400]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterStyle: GoogleFonts.inter(color: Colors.white70),
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: Colors.blue[300],
                    ),
                    filled: true,
                    fillColor: Colors.grey[900]?.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: _isUpdating ? null : () => _saveProfile(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[300],
                disabledBackgroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Save",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext dialogContext) async {
    final username = _usernameController.text.trim();

    if (!_isUsernameValid(username)) {
      _showErrorSnackBar(
        'Username harus antara 3 dan 10 karakter (huruf/angka/_)',
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await _authService.updateProfile(
        username: username,
        profilePicPath: _newProfilePic?.path,
      );

      if (mounted) {
        setState(() {
          _user = _authService.currentUser;
          _isUpdating = false;
        });
        Navigator.of(dialogContext).pop();
        _showSuccessSnackBar('Profil berhasil diupdate!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showErrorSnackBar('Gagal mengupdate profil: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue[300]),
              const SizedBox(height: 16),
              Text(
                'Memuat profil...',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat profil',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadUserProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF1A1A1A),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1A1A1A),
                        const Color(0xFF1A1A1A).withOpacity(0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Hero(
                          tag: 'profile_picture',
                          child: _buildProfilePicture(
                            _user!.profilePicPath,
                            radius: 55,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _user!.username,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user!.email,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue[300]!.withOpacity(0.2),
                                Colors.blue[400]!.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.blue[300]!.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_user!.dolarBalance} Dolar',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[300],
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: Colors.blue[300],
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(text: 'History', icon: Icon(Icons.history_outlined)),
                    Tab(text: 'Power-Ups', icon: Icon(Icons.bolt_outlined)),
                    Tab(text: 'Settings', icon: Icon(Icons.settings_outlined)),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPurchaseHistory(),
            _buildPowerUpStats(),
            _buildSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseHistory() {
    if (_user!.purchaseHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_outlined,
        title: 'Tidak ada riwayat pembelian',
        subtitle: 'Riwayat pembelian Anda akan muncul di sini',
      );
    }

    // Create a reversed list to show newest entries first
    final reversedHistory = _user!.purchaseHistory.reversed.toList();

    return ListView.builder(
      itemCount: reversedHistory.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, i) {
        final purchase = reversedHistory[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[300]!.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: purchase.type == 'Top-Up'
                    ? Colors.green[300]!.withOpacity(0.2)
                    : Colors.blue[300]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                purchase.type == 'Top-Up'
                    ? Icons.add_circle_outline
                    : Icons.shopping_bag_outlined,
                color: purchase.type == 'Top-Up'
                    ? Colors.green[300]
                    : Colors.blue[300],
              ),
            ),
            title: Text(
              purchase.type +
                  (purchase.item != null ? ' (${purchase.item})' : ''),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: FutureBuilder<String>(
              future: LocalizationHelper.formatDateTimeWithTimezone(
                purchase.date,
              ),
              builder: (context, snapshot) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    snapshot.data ?? 'Loading...',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  purchase.getFormattedAmount(),
                  style: GoogleFonts.inter(
                    color: purchase.amount > 0
                        ? Colors.green[400]
                        : Colors.red[400],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (purchase.price != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    purchase.price!,
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPowerUpStats() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPowerUpStatCard(
              '50 : 50',
              _user!.powerUpStats.fiftyFiftyUsed,
              Icons.looks_two_outlined,
              'eliminasi 2 jawaban salah',
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildPowerUpStatCard(
              'Panggil Teman',
              _user!.powerUpStats.callFriendUsed,
              Icons.phone_outlined,
              'telfon dan dapatkan bantuan dari temanmu',
              Colors.green,
            ),
            const SizedBox(height: 16),
            _buildPowerUpStatCard(
              'Audience Voting',
              _user!.powerUpStats.audienceUsed,
              Icons.people_outline,
              'lakukan voting dengan audience, dan dapatkan hasilnya',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerUpStatCard(
    String title,
    int count,
    IconData icon,
    String description,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Used $count times',
                      style: GoogleFonts.inter(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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

  Widget _buildSettings() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[300]!.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.blue[300],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Profile Picture',
                          style: GoogleFonts.inter(
                            color: Colors.blue[300],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            _buildProfilePicture(
                              _user!.profilePicPath,
                              newPic: _newProfilePic,
                              radius: 55,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[300],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_newProfilePic != null) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdating
                              ? null
                              : () => _saveProfile(context),
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isUpdating ? 'Saving...' : 'Save Picture',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[300],
                            disabledBackgroundColor: Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[300]!.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.blue[300]),
                        const SizedBox(width: 8),
                        Text(
                          'Change Username',
                          style: GoogleFonts.inter(
                            color: Colors.blue[300],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _usernameController,
                      maxLength: 10,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: GoogleFonts.inter(color: Colors.blue[300]),
                        hintText: 'Enter 3-10 characters',
                        hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                        helperText: 'Letters, numbers, and underscores only',
                        helperStyle: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.blue[300]!.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.blue[400]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterStyle: GoogleFonts.inter(color: Colors.white70),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.blue[300],
                        ),
                        filled: true,
                        fillColor: Colors.grey[900]?.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : _updateUsernameFromSettings,
                        icon: _isUpdating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isUpdating ? 'Saving...' : 'Save Changes',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[300],
                          disabledBackgroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16), // Add spacing
            // Add Logout Button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red[300]!.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A1A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red[300]),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Logout",
                                    style: GoogleFonts.inter(
                                      color: Colors.red[300],
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                "anda yakin ingin keluar?",
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    "Cancel",
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _authService.signOut();
                                    if (mounted) {
                                      // Replace pushNamedAndRemoveUntil with go_router navigation
                                      context.go('/login');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[300],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    "Logout",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: Text(
                          'Logout',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[300],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUsernameFromSettings() async {
    final username = _usernameController.text.trim();

    if (!_isUsernameValid(username)) {
      _showErrorSnackBar(
        'Username harus antara 3 dan 10 karakter (huruf/angka/_)',
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await _authService.updateProfile(username: username);
      if (mounted) {
        setState(() {
          _user = _authService.currentUser;
          _isUpdating = false;
        });
        _showSuccessSnackBar('Username berhasil diupdate!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showErrorSnackBar('Gagal mengupdate username: $e');
      }
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(
            color: Colors.blue[300]!.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

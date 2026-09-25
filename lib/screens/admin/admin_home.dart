import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_notifier.dart';
import '../auth/login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'ngo_approval_screen.dart';
import 'admin_users_screen.dart';
import 'admin_map_screen.dart';
import 'admin_donations_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_notifications_sheet.dart';
import 'about_app_screen.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ─── Logout ──────────────────────────────────────────────────
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final c = context.colors;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.borderLight),
        ),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.publicSans(
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.publicSans(
            fontSize: 14,
            color: c.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(72, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Log Out',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) _logout();
  }

  String _resolveAdminName(User? user) {
    final displayName = user?.displayName;
    final String adminNameRaw = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (user?.email?.isNotEmpty == true ? user!.email!.split('@').first : 'Sahyog Admin');
    return (adminNameRaw.toLowerCase() == 'admin') ? 'Sahyog Admin' : adminNameRaw;
  }

  Widget _buildSahyogIcon({required double size, required Color color, double padding = 6}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: Icon(Icons.volunteer_activism, color: color, size: size),
    );
  }

  Widget _buildAdminIdentity({
    required String adminName,
    required double iconSize,
    required TextStyle nameStyle,
    List<Widget>? nameExtras,
  }) {
    return Row(
      children: [
        _buildSahyogIcon(size: iconSize, color: Colors.white, padding: iconSize * 0.3),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(adminName, style: nameStyle),
              if (nameExtras != null) ...nameExtras,
            ],
          ),
        ),
      ],
    );
  }

  // ─── Settings Tab Content ─────────────────────────────────────
  Widget _buildSettingsTab() {
    final user = FirebaseAuth.instance.currentUser;
    final String adminName = _resolveAdminName(user);
    final c = context.colors;
    final lastLogin = user?.metadata.lastSignInTime;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final darkEnabled = mode == ThemeMode.dark;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SETTINGS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Admin Profile',
                style: GoogleFonts.publicSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Profile Card ─────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF9066)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: _buildAdminIdentity(
                        adminName: adminName,
                        iconSize: 28,
                        nameStyle: GoogleFonts.publicSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        nameExtras: [
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Super Admin',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 16, color: c.textSecondary),
                              const SizedBox(width: 8),
                              Text(user?.email ?? '', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                            ],
                          ),
                          if (lastLogin != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 16, color: c.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Last login: ${_formatDate(lastLogin)}',
                                  style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── APPEARANCE ───────────────────────────────────
              _settingsSectionLabel('APPEARANCE', c),
              const SizedBox(height: 10),
              _settingsCard(c, [
                _settingsToggleRow(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark Mode',
                  subtitle: darkEnabled ? 'Dark theme active' : 'Light theme active',
                  value: darkEnabled,
                  c: c,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).setDark(val);
                  },
                ),
              ]),

              const SizedBox(height: 20),

              // ── ACCOUNT ──────────────────────────────────────
              _settingsSectionLabel('ACCOUNT', c),
              const SizedBox(height: 10),
              _settingsCard(c, [
                _settingsActionRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  subtitle: 'Send reset link to your email',
                  c: c,
                  onTap: () async {
                    final email = user?.email;
                    if (email == null) return;
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password reset link sent to $email'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                ),
              ]),

              const SizedBox(height: 20),

              // ── APP INFO ─────────────────────────────────────
              _settingsSectionLabel('APP INFO', c),
              const SizedBox(height: 10),
              _settingsCard(c, [
                _settingsInfoRow(icon: Icons.info_outline_rounded, label: 'Version', value: 'v1.0.0', c: c),
                Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.4)),
                _settingsActionRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  subtitle: 'View our data usage policy',
                  c: c,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _PrivacyPolicyScreen(c: c)),
                  ),
                ),
              ]),

              const SizedBox(height: 28),

              // ── Logout ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  label: Text(
                    'LOG OUT',
                    style: GoogleFonts.publicSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  Widget _settingsSectionLabel(String label, AppColorSet c) => Text(
    label,
    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 1.2),
  );

  Widget _settingsCard(AppColorSet c, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Column(children: children),
  );

  Widget _settingsToggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required AppColorSet c,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _settingsActionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required AppColorSet c,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _settingsInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required AppColorSet c,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary))),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: c.textSecondary)),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final user = FirebaseAuth.instance.currentUser;
    final String adminName = _resolveAdminName(user);

    final screens = [
      AdminDashboardScreen(onNavigate: (i) {
        setState(() => _currentIndex = i);
      }),
      const NgoApprovalScreen(),
      const AdminDonationsScreen(),
      const AdminMapScreen(),
      const AdminReportsScreen(),
    ];

    final c = context.colors;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.background,
      appBar: _buildAppBar(adminName),
      drawer: _buildDrawer(adminName),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(c),
    );
  }

  // ─── Drawer ───────────────────────────────────────────────────
  Widget _buildDrawer(String adminName) {
    final c = context.colors;
    return Drawer(
      backgroundColor: c.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF8C5A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildSahyogIcon(size: 32, color: Colors.white, padding: 12),
                const SizedBox(height: 12),
                Text(
                  adminName,
                  style: GoogleFonts.publicSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Sahyog Admin Panel',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.people_outline, color: c.textPrimary),
            title: Text(
              'Manage Users',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
                backgroundColor: ctx.colors.background,
                appBar: AppBar(
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFFFF8C5A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text('Manage Users', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                body: const AdminUsersScreen(),
              )));
            },
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: c.textPrimary),
            title: Text(
              'About App',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: c.textPrimary),
            title: Text(
              'Settings',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
                backgroundColor: ctx.colors.background,
                appBar: AppBar(
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFFFF8C5A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text('Settings', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                body: _buildSettingsTab(),
              )));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text(
              'Logout',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmLogout();
            },
          ),
        ],
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(String adminName) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFFFF8C5A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x30FF6B35),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildAdminIdentity(
                    adminName: adminName,
                    iconSize: 18,
                    nameStyle: GoogleFonts.publicSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    nameExtras: [
                      Text(
                        'Sahyog Admin Panel',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bell icon
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => AdminNotificationsSheet.show(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────
  Widget _buildBottomNav(AppColorSet c) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Overview'),
      (Icons.verified_user_outlined, Icons.verified_user, 'Manage'),
      (Icons.monitor_heart_outlined, Icons.monitor_heart, 'Monitor'),
      (Icons.map_outlined, Icons.map_rounded, 'Track'),
      (Icons.bar_chart_outlined, Icons.bar_chart, 'Report'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = _currentIndex == i;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _currentIndex = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isActive ? item.$2 : item.$1,
                          color: isActive ? AppColors.primary : c.textSecondary,
                          size: 24,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PrivacyPolicyScreen extends StatelessWidget {
  final AppColorSet c;
  const _PrivacyPolicyScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFFFF8C5A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Privacy Policy', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policy', style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text('Last updated: August 2025', style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary)),
            const SizedBox(height: 24),
            ..._sections(colors).map((s) => _buildSection(s['title']!, s['body']!, colors)),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _sections(AppColorSet colors) => [
    {
      'title': '1. Information We Collect',
      'body': 'Sahyog collects information necessary to facilitate food donation and distribution. This includes donor details (name, contact, pickup address), NGO information, volunteer profiles, and donation records. All data is stored securely on Firebase.'
    },
    {
      'title': '2. How We Use Your Information',
      'body': 'We use collected data solely to match donors with NGOs, coordinate volunteer pickups, generate platform reports, and improve our service. We do not sell or share your personal information with third parties.'
    },
    {
      'title': '3. Data Storage & Security',
      'body': 'All data is stored on Google Firebase, which employs industry-standard encryption. Admin access is restricted to authorized personnel only. Passwords are never stored in plain text.'
    },
    {
      'title': '4. Data Retention',
      'body': 'Donation records are retained for up to 2 years for audit and reporting purposes. User accounts that remain inactive for over 12 months may be removed by administrators.'
    },
    {
      'title': '5. Your Rights',
      'body': 'Users may request deletion of their account and associated data at any time by contacting the platform administrator. NGOs and donors can update their profile information through the app.'
    },
    {
      'title': '6. Contact',
      'body': 'For any privacy-related queries, please contact the Sahyog Admin team at admin@sahyog.org.'
    },
  ];

  Widget _buildSection(String title, String body, AppColorSet colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 6),
          Text(body, style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary, height: 1.6)),
        ],
      ),
    );
  }
}

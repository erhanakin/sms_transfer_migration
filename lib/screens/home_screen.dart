import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/admob_banner.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';
import '../utils/permissions.dart';
import 'sender_screen.dart';
import 'receiver_screen.dart';
import 'export_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AdMobService _adMobService = AdMobService();

  @override
  void initState() {
    super.initState();
    _initializeAds();
  }

  void _initializeAds() {
    _adMobService.preloadAds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Transfer & Migration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Card
                    _buildWelcomeCard(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // WiFi Notice Card
                    _buildWiFiNoticeCard(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Main Features
                    _buildFeatureSection(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Quick Stats
                    _buildQuickStatsCard(),

                    const SizedBox(height: AppDimensions.paddingLarge),

                    // Recent Activity
                    _buildRecentActivityCard(),
                  ],
                ),
              ),
            ),
            // AdMob Banner
            const AdMobBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.message,
                  size: AppDimensions.iconSizeLarge,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to SMS Transfer',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingSmall),
                      Text(
                        'Transfer SMS messages between devices or export them to various formats',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWiFiNoticeCard() {
    return Card(
      color: AppColors.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi,
                  size: AppDimensions.iconSizeLarge,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(width: AppDimensions.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WiFi Transfer Notice',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingSmall),
                      Text(
                        'For SMS transfer between devices, both phones must be connected to the same WiFi network.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryColor,
                    size: AppDimensions.iconSizeMedium,
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: Text(
                      '• Connect both devices to the same WiFi\n• Use "Send SMS" on source device\n• Use "Receive SMS" on target device\n• Keep both apps open during transfer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
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

  Widget _buildFeatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Main Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingMedium),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.send,
                title: 'Send SMS',
                subtitle: 'Transfer messages to another device',
                color: AppColors.primaryColor,
                onTap: () => _navigateToSender(),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingMedium),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.download,
                title: 'Receive SMS',
                subtitle: 'Receive messages from another device',
                color: AppColors.accentColor,
                onTap: () => _navigateToReceiver(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingMedium),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.file_download,
                title: 'Export SMS',
                subtitle: 'Export to CSV, XLSX, JSON, TXT',
                color: AppColors.successColor,
                onTap: () => _navigateToExport(),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingMedium),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'App settings and preferences',
                color: AppColors.warningColor,
                onTap: () => _navigateToSettings(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeXLarge,
                color: color,
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeMedium,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  'Quick Stats',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.message,
                    label: 'Total Messages',
                    value: '0',
                    color: AppColors.primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.file_copy,
                    label: 'Exports',
                    value: '0',
                    color: AppColors.successColor,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.sync,
                    label: 'Transfers',
                    value: '0',
                    color: AppColors.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            ElevatedButton.icon(
              onPressed: () => _checkPermissionsAndLoadStats(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Stats'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: AppDimensions.iconSizeLarge,
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: AppColors.primaryColor,
                  size: AppDimensions.iconSizeMedium,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: AppDimensions.iconSizeMedium,
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: Text(
                      'No recent activity. Start by transferring or exporting SMS messages.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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

  Future<void> _checkPermissionsAndLoadStats() async {
    final hasPermissions = await PermissionManager.ensurePermissionsForFeature(
      context,
      'sms',
    );

    if (hasPermissions) {
      // TODO: Load actual SMS statistics
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Statistics refreshed'),
          backgroundColor: AppColors.successColor,
        ),
      );
    }
  }

  void _navigateToSender() async {
    final hasPermissions = await PermissionManager.ensurePermissionsForFeature(
      context,
      'transfer',
    );

    if (hasPermissions) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SenderScreen()),
      );
    }
  }

  void _navigateToReceiver() async {
    final hasPermissions = await PermissionManager.ensurePermissionsForFeature(
      context,
      'transfer',
    );

    if (hasPermissions) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReceiverScreen()),
      );
    }
  }

  void _navigateToExport() async {
    final hasPermissions = await PermissionManager.ensurePermissionsForFeature(
      context,
      'export',
    );

    if (hasPermissions) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ExportScreen()),
      );
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  void dispose() {
    _adMobService.dispose();
    super.dispose();
  }
}
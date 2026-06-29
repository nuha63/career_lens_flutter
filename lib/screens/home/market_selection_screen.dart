import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../utils/helpers.dart';

class MarketSelectionScreen extends StatefulWidget {
  const MarketSelectionScreen({super.key});

  @override
  State<MarketSelectionScreen> createState() => _MarketSelectionScreenState();
}

class _MarketSelectionScreenState extends State<MarketSelectionScreen> {
  String? _selectedMarket;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedMarket();
  }

  Future<void> _loadSavedMarket() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMarket = prefs.getString(AppConstants.keyJobMarket);
    if (savedMarket != null) {
      setState(() => _selectedMarket = savedMarket);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedMarket == null) {
      Helpers.showErrorToast('Please select a job market');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyJobMarket, _selectedMarket!);

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.resumeUpload,
        arguments: {'market': _selectedMarket},
      );

      Helpers.showSuccessToast(
        _selectedMarket == AppConstants.marketBangladesh
            ? 'Bangladesh market selected 🇧🇩'
            : 'Global market selected 🌍',
      );
    } catch (e) {
      Helpers.showErrorToast('Failed to save selection: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Job Market'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Choose Your Target Market',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Select the job market you want to target for personalized AI insights',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),

            const SizedBox(height: 40),

            // Bangladesh Market Card
            _buildMarketCard(
              flag: '🇧🇩',
              title: 'Bangladesh Market',
              description:
                  'Get insights tailored for Bangladesh job market with local companies, skills, and requirements',
              value: AppConstants.marketBangladesh,
              isSelected: _selectedMarket == AppConstants.marketBangladesh,
              onTap: () {
                setState(() => _selectedMarket = AppConstants.marketBangladesh);
              },
            ),

            const SizedBox(height: 16),

            // Global Market Card
            _buildMarketCard(
              flag: '🌍',
              title: 'Global Market',
              description:
                  'Get insights for international job market with global companies, skills, and requirements',
              value: AppConstants.marketGlobal,
              isSelected: _selectedMarket == AppConstants.marketGlobal,
              onTap: () {
                setState(() => _selectedMarket = AppConstants.marketGlobal);
              },
            ),

            const SizedBox(height: 40),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketCard({
    required String flag,
    required String title,
    required String description,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flag emoji
            Text(
              flag,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimary,
                              ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
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
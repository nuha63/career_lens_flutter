import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../repositories/job_match_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/premium_lock_widget.dart';

class SalaryPredictionScreen extends StatefulWidget {
  const SalaryPredictionScreen({super.key});

  @override
  State<SalaryPredictionScreen> createState() => _SalaryPredictionScreenState();
}

class _SalaryPredictionScreenState extends State<SalaryPredictionScreen> {
  // ── Repositories ─────────────────────────────────────────────────────────
  final JobMatchRepository  _jobMatchRepo = JobMatchRepository();
  final AuthRepository      _authRepo     = AuthRepository();
  final AppCacheService     _cache        = AppCacheService();
  final ConnectivityService _conn         = ConnectivityService();

  String? _userId;
  bool    _isPredicting = false;
  bool    _isOffline    = false;

  // ── Form fields ───────────────────────────────────────────────────────────
  String _companySize  = 'Medium';
  String _industry     = 'IT';
  bool   _remoteOption = true;
  int    _numSkills    = 5;

  // ── Result state ──────────────────────────────────────────────────────────
  /// Current-session prediction result (from a fresh API call)
  Map<String, dynamic>? _salaryResult;

  /// Previous-session cached result (loaded on startup)
  Map<String, dynamic>? _cachedSalary;
  String?               _cachedSalaryAge;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await _authRepo.getUserId();
    // Load last cached salary (stale OK) for instant display
    await _loadCachedSalary();
    // Check connectivity for offline banner
    final online = await _conn.checkConnectivity();
    if (mounted) setState(() => _isOffline = !online);
  }

  // ── Step 1: Show last cached salary immediately ───────────────────────────
  Future<void> _loadCachedSalary() async {
    final entry = await _cache.loadLastSalaryWithMeta();
    if (entry != null && mounted) {
      setState(() {
        _cachedSalary    = entry.data;
        _cachedSalaryAge = entry.ageLabel;
      });
    }
  }

  // ── Step 2: Fresh salary prediction via repository ────────────────────────
  Future<void> _predictSalary() async {
    if (_isOffline) {
      Helpers.showErrorToast('No network connection. Showing last cached prediction.');
      if (_cachedSalary != null && mounted) {
        setState(() => _salaryResult = _cachedSalary);
      }
      return;
    }

    setState(() => _isPredicting = true);

    try {
      final bundle = await _jobMatchRepo.predictSalary(
        companySize:  _companySize,
        industry:     _industry,
        remoteOption: _remoteOption,
        numSkills:    _numSkills,
        userId:       _userId,
      );

      if (mounted) {
        setState(() {
          _salaryResult = {
            'salary_min': bundle.salaryMin,
            'salary_max': bundle.salaryMax,
            'salary_avg': bundle.salaryAvg,
          };
          // Update the cached preview too
          _cachedSalary    = _salaryResult;
          _cachedSalaryAge = 'just now';
        });
        Helpers.showSuccessToast('Salary prediction complete!');
      }
    } catch (e) {
      // On failure, fall back to last cached salary if available
      if (_cachedSalary != null && mounted) {
        setState(() => _salaryResult = _cachedSalary);
        Helpers.showErrorToast('Using cached result: ${e.toString()}');
      } else {
        Helpers.showErrorToast('Prediction failed: $e');
      }
      debugPrint('SalaryPrediction error: $e');
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumLockWidget(
      featureName: 'AI Salary Prediction',
      child: _salaryResult != null 
        ? _buildResultView() 
        : Scaffold(
            appBar: AppBar(title: const Text('Salary Prediction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Text('Predict Your Salary',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('AI-powered salary estimation based on market data',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),

            // ── Offline banner ─────────────────────────────────────────────
            if (_isOffline) _buildOfflineBanner(),

            // ── Last cached salary preview card ────────────────────────────
            if (_cachedSalary != null) ...[
              _buildCachedSalaryCard(),
              const SizedBox(height: 24),
            ],

            // ── Form ───────────────────────────────────────────────────────
            _buildDropdown(
              label: 'Company Size', value: _companySize,
              items: ['Small', 'Medium', 'Large'],
              onChanged: (v) { if (v != null) setState(() => _companySize = v); },
            ),
            const SizedBox(height: 20),
            _buildDropdown(
              label: 'Industry', value: _industry,
              items: ['IT', 'Finance', 'Healthcare', 'Manufacturing', 'Education', 'Other'],
              onChanged: (v) { if (v != null) setState(() => _industry = v); },
            ),
            const SizedBox(height: 20),

            // Remote toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remote Position',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text('Remote positions typically have different salary ranges',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value:     _remoteOption,
                    onChanged: (v) => setState(() => _remoteOption = v),
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSlider(
              label:     'Number of Key Skills: $_numSkills',
              value:     _numSkills.toDouble(),
              min:       1,
              max:       20,
              onChanged: (v) => setState(() => _numSkills = v.toInt()),
            ),
            const SizedBox(height: 32),
            CustomButton(
              label:     _isPredicting ? 'Predicting…' : 'Predict Salary',
              onPressed: _isPredicting ? null : _predictSalary,
              isLoading: _isPredicting,
            ),
          ],
        ),
      ),
    ));
  }

  // ── Last cached salary preview ─────────────────────────────────────────────
  Widget _buildCachedSalaryCard() {
    // Display the raw monthly value (which the user perceives as monthly BDT)
    final avg = ((_cachedSalary!['salary_avg'] as num?)?.toInt() ?? 0);
    final min = ((_cachedSalary!['salary_min'] as num?)?.toInt() ?? 0);
    final max = ((_cachedSalary!['salary_max'] as num?)?.toInt() ?? 0);

    return GestureDetector(
      onTap: () => setState(() => _salaryResult = _cachedSalary),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: Colors.green.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('Last Prediction · $_cachedSalaryAge',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
                const Spacer(),
                Text('View →',
                    style: TextStyle(fontSize: 12, color: Colors.green,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniSalaryCol('Min',  min,  Colors.orange),
                _buildMiniSalaryCol('Avg',  avg,  Colors.green),
                _buildMiniSalaryCol('Max',  max,  Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSalaryCol(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text('Tk ${_formatCurrency(amount)}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ── Offline banner ─────────────────────────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppTheme.errorColor.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 16, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _cachedSalary != null
                    ? '📶 Offline – tap the card above to view your last cached prediction'
                    : '📶 Offline – no cached prediction available.',
                style: TextStyle(fontSize: 12, color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Full result view ───────────────────────────────────────────────────────
  Widget _buildResultView() {
    // Display the raw monthly value (which the user perceives as monthly BDT)
    final min = ((_salaryResult?['salary_min'] as num?)?.toInt() ?? 0);
    final max = ((_salaryResult?['salary_max'] as num?)?.toInt() ?? 0);
    final avg = ((_salaryResult?['salary_avg'] as num?)?.toInt() ?? 0);
    final isFromCache = _salaryResult == _cachedSalary &&
        _cachedSalaryAge != 'just now';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Prediction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _salaryResult = null),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cache label
            if (isFromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:        AppTheme.warningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppTheme.warningColor.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cached, size: 14, color: AppTheme.warningColor),
                      const SizedBox(width: 8),
                      Text('Cached prediction from $_cachedSalaryAge',
                          style: TextStyle(fontSize: 12, color: AppTheme.warningColor)),
                    ],
                  ),
                ),
              ),

            Text('Predicted Salary Range',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),

            // Average salary hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.green.withValues(alpha: 0.8),
                  Colors.teal.withValues(alpha: 0.6),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Average Salary',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 16),
                  Text('Tk ${_formatCurrency(avg)}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Per Month',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Min / Max row
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border:       Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSalaryColumn(title: 'Minimum', amount: min, color: Colors.orange),
                  Container(width: 1, height: 80,
                      color: Colors.grey.withValues(alpha: 0.2)),
                  _buildSalaryColumn(title: 'Maximum', amount: max, color: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Based on section
            Text('Based on:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildDetailChip('Company Size', _companySize),
            _buildDetailChip('Industry',    _industry),
            _buildDetailChip('Remote',      _remoteOption ? 'Yes' : 'No'),
            _buildDetailChip('Key Skills',  '$_numSkills'),
            const SizedBox(height: 32),

            // Insight box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Text('Market Insight',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This salary prediction is based on current market data and may vary '
                    'based on location, experience, and specific skills.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.blue.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            CustomButton(
              label:     'New Prediction',
              onPressed: () => setState(() => _salaryResult = null),
              icon:      Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryColumn({
    required String title,
    required int    amount,
    required Color  color,
  }) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Text('Tk ${_formatCurrency(amount)}',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppTheme.textSecondary)),
          Chip(
            label:           Text(value),
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            labelStyle:      TextStyle(color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String              label,
    required String              value,
    required List<String>        items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value:      value,
          isExpanded: true,
          items:      items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged:  onChanged,
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String               label,
    required double               value,
    required double               min,
    required double               max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Slider(value: value, min: min, max: max,
            onChanged: onChanged, activeColor: AppTheme.primaryColor),
      ],
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},',
    );
  }
}

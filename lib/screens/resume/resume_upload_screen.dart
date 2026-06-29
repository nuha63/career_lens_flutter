import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/resume_model.dart';
import '../../repositories/resume_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class ResumeUploadScreen extends StatefulWidget {
  final String selectedMarket;

  const ResumeUploadScreen({
    super.key,
    required this.selectedMarket,
  });

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  // ── Repositories / Services ──────────────────────────────────────────────
  final ResumeRepository    _resumeRepo = ResumeRepository();
  final AuthRepository      _authRepo   = AuthRepository();
  final AppCacheService     _cache      = AppCacheService();
  final ConnectivityService _conn       = ConnectivityService();

  // ── Upload state ─────────────────────────────────────────────────────────
  // We use bytes + filename instead of File so this works on Flutter Web too
  Uint8List? _selectedFileBytes;
  String?   _selectedFileName;
  bool  _isUploading = false;
  bool  _isOffline   = false;

  // ── Cached last-analysis state (shown on startup) ─────────────────────────
  ResumeAnalysisResult? _cachedResult;
  String?               _cachedResultAge;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadLastCachedResult();
    final online = await _conn.checkConnectivity();
    if (mounted) setState(() => _isOffline = !online);
  }

  /// Load the last cached resume analysis (stale reads allowed) for instant display.
  Future<void> _loadLastCachedResult() async {
    final entry = await _cache.loadLastResumeWithMeta();
    if (entry != null && mounted) {
      setState(() {
        _cachedResult    = entry.data;
        _cachedResultAge = entry.ageLabel;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedFileTypes,
        // withData: true ensures bytes are available on web
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final fileBytes = result.files.single.bytes!;
        final fileName  = result.files.single.name;
        final fileSize  = fileBytes.length;

        // Validate file size
        if (!Helpers.validateFileSize(fileSize, maxMB: AppConstants.maxFileSizeMB)) {
          Helpers.showErrorToast(
            'File size exceeds \${AppConstants.maxFileSizeMB}MB limit',
          );
          return;
        }

        // Validate file type
        if (!Helpers.validateFileType(fileName, AppConstants.allowedFileTypes)) {
          Helpers.showErrorToast(
            'Invalid file type. Please upload PDF or DOC file',
          );
          return;
        }

        setState(() {
          _selectedFileBytes = fileBytes;
          _selectedFileName  = fileName;
        });
        Helpers.showSuccessToast('File selected: $fileName');
      }
    } catch (e) {
      Helpers.showErrorToast('Failed to pick file: $e');
    }
  }

  Future<void> _uploadAndAnalyze() async {
    if (_selectedFileBytes == null) {
      Helpers.showErrorToast('Please select a resume file');
      return;
    }
    if (_isOffline) {
      Helpers.showErrorToast('No network connection. Cannot upload resume offline.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = await _authRepo.getUserId();

      // ResumeRepository handles upload + ML analysis + caching automatically
      final bundle = await _resumeRepo.uploadAndAnalyze(
        fileBytes: _selectedFileBytes!,
        fileName:  _selectedFileName!,
        market: widget.selectedMarket,
        userId: userId,
      );

      if (!mounted) return;

      // Update the cached preview so it's visible on next visit
      setState(() {
        _cachedResult    = bundle.uploadResult;
        _cachedResultAge = 'just now';
        _selectedFileBytes = null;
        _selectedFileName  = null;
      });

      // Navigate to results with the full bundle
      Navigator.pushNamed(
        context,
        AppRoutes.resumeResult,
        arguments: {
          'result':              bundle.uploadResult,
          'ml_match_percentage': bundle.mlMatchPercentage,
          'strengths':           bundle.strengths,
          'weaknesses':          bundle.weaknesses,
          'ml_suggestions':      bundle.mlSuggestions,
        },
      );

      Helpers.showSuccessToast('Resume analyzed successfully! 🎉');
    } catch (e) {
      Helpers.showErrorToast('Analysis failed: $e');
      debugPrint('ResumeUpload error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Resume'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Offline banner ─────────────────────────────────────────────
            if (_isOffline)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:        AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppTheme.errorColor.withOpacity(0.22)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, size: 16, color: AppTheme.errorColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📶 Offline – resume upload requires a network connection.',
                          style: TextStyle(fontSize: 12, color: AppTheme.errorColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Last analysis preview card (from cache) ────────────────────
            if (_cachedResult != null) ...[_buildLastAnalysisCard(), const SizedBox(height: 24)],
            // Market indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.selectedMarket == AppConstants.marketBangladesh
                        ? '🇧🇩 Bangladesh Market'
                        : '🌍 Global Market',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'Upload Your Resume',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your resume to get AI-powered ATS score and skill analysis',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),

            const SizedBox(height: 32),

            // Upload area
            InkWell(
              onTap: _isUploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: DottedBorder(
                borderType: BorderType.RRect,
                radius: const Radius.circular(16),
                dashPattern: const [8, 4],
                color: _selectedFileBytes != null
                  ? AppTheme.successColor
                  : AppTheme.primaryColor.withOpacity(0.5),
                strokeWidth: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _selectedFileBytes != null 
                    ? AppTheme.successColor.withOpacity(0.05)
                    : AppTheme.primaryColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFileBytes != null
                        ? Icons.check_circle
                        : Icons.cloud_upload_outlined,
                    size: 64,
                    color: _selectedFileBytes != null
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFileBytes != null
                          ? 'File Selected ✓'
                          : 'Tap to Upload Resume',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _selectedFileBytes != null
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedFileBytes != null) ...[
                      Text(
                        _selectedFileName ?? '',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.getFileSizeString(_selectedFileBytes!.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else ...[
                      Text(
                        'Supported formats: PDF, DOC, DOCX',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Max size: ${AppConstants.maxFileSizeMB}MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ), // Close InkWell

            const SizedBox(height: 24),

            // Tips section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppTheme.infoColor),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for Best Results',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.infoColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipItem('Use a well-formatted resume'),
                  _buildTipItem('Include clear section headings'),
                  _buildTipItem('List your skills explicitly'),
                  _buildTipItem('Mention relevant experience'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Analyze button
            CustomButton(
              label: 'Analyze Resume',
              onPressed: _uploadAndAnalyze,
              isLoading: _isUploading,
              icon: Icons.analytics,
            ),

            if (_selectedFileBytes != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () {
                      setState(() {
                        _selectedFileBytes = null;
                        _selectedFileName  = null;
                      });
                        },
                  icon: const Icon(Icons.close),
                  label: const Text('Remove File'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppTheme.infoColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ── Last-analysis cache card ──────────────────────────────────────────────
  Widget _buildLastAnalysisCard() {
    final score = _cachedResult!.atsScore;
    final color = AppTheme.getATSScoreColor(score);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.resumeResult,
        arguments: {'result': _cachedResult},
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withOpacity(0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('Last Analysis · $_cachedResultAge',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
                const Spacer(),
                Text('View →',
                    style: TextStyle(fontSize: 12, color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // ATS score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('ATS ${score}%',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cachedResult!.market == AppConstants.marketBangladesh
                            ? '🇧🇩 Bangladesh Market'
                            : '🌍 Global Market',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_cachedResult!.detectedSkills.length} skills detected',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
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

  @override
  void dispose() {
    super.dispose();
  }
}
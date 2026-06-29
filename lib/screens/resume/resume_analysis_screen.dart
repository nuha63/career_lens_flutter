import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/resume_model.dart';
import '../../services/api_service.dart';
import '../../services/ml_api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class ResumeAnalysisScreen extends StatefulWidget {
  final String selectedMarket;

  const ResumeAnalysisScreen({
    super.key,
    required this.selectedMarket,
  });

  @override
  State<ResumeAnalysisScreen> createState() => _ResumeAnalysisScreenState();
}

class _ResumeAnalysisScreenState extends State<ResumeAnalysisScreen> {
  File? _selectedFile;
  bool _isAnalyzing = false;
  String? _userId;
  
  final ApiService _apiService = ApiService();
  final MLApiService _mlService = getMLApiService();
  final AuthService _authService = AuthService();

  // Form fields for ML analysis
  int _experienceYears = 3;
  String _educationLevel = 'Bachelor';
  double _skillsMatchScore = 75.0;
  String _industry = 'IT';

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString(AppConstants.keyUserId);
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedFileTypes,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        // Validate file size
        if (!Helpers.validateFileSize(fileSize, maxMB: AppConstants.maxFileSizeMB)) {
          Helpers.showErrorToast(
            'File size exceeds ${AppConstants.maxFileSizeMB}MB limit',
          );
          return;
        }

        setState(() => _selectedFile = file);
        Helpers.showSuccessToast('File selected: ${result.files.single.name}');
      }
    } catch (e) {
      Helpers.showErrorToast('Failed to pick file: $e');
    }
  }

  Future<void> _analyzeResume() async {
    if (_selectedFile == null) {
      Helpers.showErrorToast('Please select a resume file');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // Call ML service to analyze resume
      final mlResult = await _mlService.analyzeResume(
        experienceYears: _experienceYears,
        educationLevel: _educationLevel,
        skillsMatchScore: _skillsMatchScore,
        industry: _industry,
        userId: _userId,
      );

      if (!mounted) return;

      // Extract data from response
      final data = mlResult['data'] as Map<String, dynamic>?;
      
      if (data != null) {
        // Create result and navigate
        final analysisResult = ResumeAnalysisResult(
        resumeId: (data['resume_id'] ?? '').toString(),
        resumeText: (data['resume_text'] ?? '').toString(),
        atsScore: (data['ats_score'] as num?)?.toInt() ?? 0,
        detectedSkills: List<String>.from(data['detected_skills'] ?? []),
        suggestions: List<String>.from(data['suggestions'] ?? []),
        statistics: (data['statistics'] as Map<String, dynamic>?) ?? {},
        market: widget.selectedMarket,
          );

        Navigator.pushNamed(
          context,
          AppRoutes.resumeResult,
          arguments: {'result': analysisResult},
        );

        Helpers.showSuccessToast('Resume analyzed successfully!');
      } else {
        Helpers.showErrorToast('Invalid response from ML service');
      }
    } catch (e) {
      Helpers.showErrorToast('Analysis failed: $e');
      debugPrint('Resume analysis error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Market indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
               widget.selectedMarket == AppConstants.marketBangladesh
                    ? '🇧🇩 Bangladesh Market'
                    : '🌍 Global Market',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Analyze Your Resume',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'ML-powered resume scoring & recommendations',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // File selection
            GestureDetector(
              onTap: _isAnalyzing ? null : _pickFile,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.primaryColor.withOpacity(0.05),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFile?.path.split('/').last ?? 'Select Resume File',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFile == null)
                      Text(
                        'PDF or DOC files only',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ML Parameters
            Text(
              'Profile Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Experience Years
            _buildSlider(
              label: 'Experience Years: $_experienceYears',
              value: _experienceYears.toDouble(),
              min: 0,
              max: 20,
              onChanged: (value) {
                setState(() => _experienceYears = value.toInt());
              },
            ),
            const SizedBox(height: 16),

            // Education Level
            _buildDropdown(
              label: 'Education Level',
              value: _educationLevel,
              items: ['High School', 'Bachelor', 'Master', 'PhD'],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _educationLevel = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Skills Match
            _buildSlider(
              label: 'Skills Match Score: ${_skillsMatchScore.toStringAsFixed(0)}%',
              value: _skillsMatchScore,
              min: 0,
              max: 100,
              onChanged: (value) {
                setState(() => _skillsMatchScore = value);
              },
            ),
            const SizedBox(height: 16),

            // Industry
            _buildDropdown(
              label: 'Industry',
              value: _industry,
              items: ['IT', 'Finance', 'Healthcare', 'Manufacturing', 'Other'],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _industry = value);
                }
              },
            ),
            const SizedBox(height: 32),

            // Analyze Button
            CustomButton(
              label: _isAnalyzing ? 'Analyzing...' : 'Analyze Resume',
              onPressed: _isAnalyzing ? null : _analyzeResume,
              isLoading: _isAnalyzing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

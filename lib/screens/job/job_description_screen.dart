import 'package:flutter/material.dart';
//import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/resume_model.dart';
import '../../services/api_service.dart';
//import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../repositories/job_match_repository.dart';

class JobDescriptionScreen extends StatefulWidget {
  final dynamic resumeData;

  const JobDescriptionScreen({
    super.key,
    this.resumeData,
  });

  @override
  State<JobDescriptionScreen> createState() => _JobDescriptionScreenState();
}

class _JobDescriptionScreenState extends State<JobDescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobDescriptionController = TextEditingController();
  bool _isAnalyzing = false;
  String _selectedMarket = AppConstants.marketBangladesh;
  final JobMatchRepository _jobMatchRepo = JobMatchRepository();

  @override
  void initState() {
    super.initState();
    _loadMarket();
  }

  Future<void> _loadMarket() async {
    final prefs = await SharedPreferences.getInstance();
    final market = prefs.getString(AppConstants.keyJobMarket);
    if (market != null) {
      setState(() => _selectedMarket = market);
    }
  }

  Future<void> _analyzeJobMatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAnalyzing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.keyUserId);

      if (userId == null || userId.isEmpty) {
        throw 'User not authenticated';
      }

      final resumeText = widget.resumeData is ResumeAnalysisResult
          ? (widget.resumeData as ResumeAnalysisResult).resumeText
          : null;
          
      final atsScore = widget.resumeData is ResumeAnalysisResult
          ? (widget.resumeData as ResumeAnalysisResult).atsScore
          : 70;

      // Extract a dummy job title from the first line of the text box
      final descriptionLines = _jobDescriptionController.text.trim().split('\n');
      final jobTitle = descriptionLines.isNotEmpty && descriptionLines.first.length < 50
          ? descriptionLines.first
          : 'Software Engineer';

      final bundle = await _jobMatchRepo.matchJob(
        jobTitle: jobTitle,
        company: 'Unknown',
        industry: 'IT',
        resumeScore: atsScore / 100.0,
        skillsMatchScore: 80.0, // Default baseline
        experienceYears: 2,
        educationLevel: 'Bachelor',
        userId: userId,
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.jobMatch,
        arguments: {
          'result': bundle.matchResult,
        },
      );

      Helpers.showSuccessToast('Job match analysis complete! 🎉');
    } catch (e) {
      Helpers.showErrorToast('Analysis failed: $e');
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
        title: const Text('Job Description'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Paste Job Description',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Copy and paste the job description you want to apply for',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),

              const SizedBox(height: 24),

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
                      _selectedMarket == AppConstants.marketBangladesh
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

              // Job description field
              TextFormField(
                controller: _jobDescriptionController,
                maxLines: 15,
                validator: (value) =>
                    Validators.validateTextArea(value, minLength: 50),
                decoration: const InputDecoration(
                  labelText: 'Job Description',
                  hintText: 'Paste the complete job description here...\n\n'
                      'Include:\n'
                      '• Job title\n'
                      '• Required skills\n'
                      '• Responsibilities\n'
                      '• Qualifications',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.infoColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.infoColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Our AI will compare your resume with the job description to:',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Calculate match percentage\n'
                            '• Identify matched skills\n'
                            '• Find missing skills\n'
                            '• Provide improvement suggestions',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Analyze button
              CustomButton(
                label: 'Analyze Job Match',
                onPressed: _analyzeJobMatch,
                isLoading: _isAnalyzing,
                icon: Icons.analytics,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _jobDescriptionController.dispose();
    super.dispose();
  }
}
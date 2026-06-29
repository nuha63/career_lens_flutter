import '../models/career_roadmap_model.dart';

/// Provides production-grade fallback templates for Career Roadmaps
/// to guarantee the application never shows an empty state.
class RoadmapTemplateEngine {
  
  /// Get all available templates
  static List<CareerRoadmap> get allTemplates => [
        _flutterTemplate,
        _sqaTemplate,
        _defaultTemplate,
      ];

  /// Find template by ID or matching career name
  static CareerRoadmap getTemplate(String identifier) {
    final cleanId = identifier.trim().toLowerCase();
    
    if (cleanId.contains('flutter') || cleanId == '3' || cleanId.contains('phone_android')) {
      return _flutterTemplate;
    } else if (cleanId.contains('sqa') || cleanId.contains('qa') || cleanId.contains('test') || cleanId == '10' || cleanId.contains('fact_check')) {
      return _sqaTemplate;
    }
    
    return _defaultTemplate;
  }

  // ==================== TEMPLATES DEFINITIONS ====================

  static final CareerRoadmap _flutterTemplate = CareerRoadmap(
    id: 'flutter_template',
    careerName: 'Flutter Developer',
    description: 'Build beautiful cross-platform mobile apps for iOS and Android using Flutter and Dart.',
    estimatedDuration: '6-8 months',
    iconName: 'phone_android',
    totalPhases: 6,
    completedPhases: 0,
    overallCompletionPercentage: 0,
    phases: [
      const RoadmapPhase(
        id: 'flutter_ph1',
        roadmapId: 'flutter_template',
        phaseNumber: 1,
        phaseTitle: 'Dart Programming Language',
        phaseDescription: 'Learn Dart fundamentals: variables, control flow, functions, classes, OOP, generics, async/await, and streams.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Dart'), RoadmapSkill(id: 'template_skill_1', skillName: 'OOP'), RoadmapSkill(id: 'template_skill_2', skillName: 'Async/Await'), RoadmapSkill(id: 'template_skill_3', skillName: 'Streams')],
      ),
      const RoadmapPhase(
        id: 'flutter_ph2',
        roadmapId: 'flutter_template',
        phaseNumber: 2,
        phaseTitle: 'Flutter Basics & Widgets',
        phaseDescription: 'Understand the Flutter widget tree. Build responsive user interfaces with StatelessWidget, StatefulWidget, and common layout widgets.',
        estimatedWeeks: 4,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Flutter SDK'), RoadmapSkill(id: 'template_skill_1', skillName: 'Widgets'), RoadmapSkill(id: 'template_skill_2', skillName: 'Layouts'), RoadmapSkill(id: 'template_skill_3', skillName: 'Material Design')],
      ),
      const RoadmapPhase(
        id: 'flutter_ph3',
        roadmapId: 'flutter_template',
        phaseNumber: 3,
        phaseTitle: 'State Management',
        phaseDescription: 'Master modern state management patterns: Provider, Riverpod, or BLoC. Learn how to manage application state cleanly.',
        estimatedWeeks: 4,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Provider'), RoadmapSkill(id: 'template_skill_1', skillName: 'Riverpod'), RoadmapSkill(id: 'template_skill_2', skillName: 'BLoC'), RoadmapSkill(id: 'template_skill_3', skillName: 'State Management')],
      ),
      const RoadmapPhase(
        id: 'flutter_ph4',
        roadmapId: 'flutter_template',
        phaseNumber: 4,
        phaseTitle: 'API Integration & Local Database',
        phaseDescription: 'Connect mobile apps to REST APIs using http/dio package. Persist data locally with SharedPreferences and SQLite.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'REST APIs'), RoadmapSkill(id: 'template_skill_1', skillName: 'Dio'), RoadmapSkill(id: 'template_skill_2', skillName: 'SharedPreferences'), RoadmapSkill(id: 'template_skill_3', skillName: 'SQLite')],
      ),
      const RoadmapPhase(
        id: 'flutter_ph5',
        roadmapId: 'flutter_template',
        phaseNumber: 5,
        phaseTitle: 'Navigation & Clean Architecture',
        phaseDescription: 'Implement routing with GoRouter, deep linking, and follow Clean Architecture (Repository and Service patterns).',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Navigation'), RoadmapSkill(id: 'template_skill_1', skillName: 'GoRouter'), RoadmapSkill(id: 'template_skill_2', skillName: 'Clean Architecture'), RoadmapSkill(id: 'template_skill_3', skillName: 'DI (GetIt)')],
      ),
      const RoadmapPhase(
        id: 'flutter_ph6',
        roadmapId: 'flutter_template',
        phaseNumber: 6,
        phaseTitle: 'Testing, Deployment & Store Publishing',
        phaseDescription: 'Write unit, widget, and integration tests. Build release versions and publish applications to Google Play and Apple App Store.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Unit Testing'), RoadmapSkill(id: 'template_skill_1', skillName: 'Widget Testing'), RoadmapSkill(id: 'template_skill_2', skillName: 'Play Store'), RoadmapSkill(id: 'template_skill_3', skillName: 'App Store'), RoadmapSkill(id: 'template_skill_4', skillName: 'CI/CD')],
      ),
    ],
  );

  static final CareerRoadmap _sqaTemplate = CareerRoadmap(
    id: 'sqa_template',
    careerName: 'SQA Engineer',
    description: 'Ensure software quality through systematic testing, test automation, and quality assurance processes.',
    estimatedDuration: '6-8 months',
    iconName: 'fact_check',
    totalPhases: 6,
    completedPhases: 0,
    overallCompletionPercentage: 0,
    phases: [
      const RoadmapPhase(
        id: 'sqa_ph1',
        roadmapId: 'sqa_template',
        phaseNumber: 1,
        phaseTitle: 'Software Testing Fundamentals',
        phaseDescription: 'Understand SDLC/STLC, manual testing methodologies, test planning, writing test cases, and the bug lifecycle using JIRA.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'SDLC/STLC'), RoadmapSkill(id: 'template_skill_1', skillName: 'Test Planning'), RoadmapSkill(id: 'template_skill_2', skillName: 'Test Case Writing'), RoadmapSkill(id: 'template_skill_3', skillName: 'Bug Lifecycle'), RoadmapSkill(id: 'template_skill_4', skillName: 'JIRA')],
      ),
      const RoadmapPhase(
        id: 'sqa_ph2',
        roadmapId: 'sqa_template',
        phaseNumber: 2,
        phaseTitle: 'Manual Testing Techniques',
        phaseDescription: 'Practice black-box testing, boundary value analysis, equivalence partitioning, regression testing, and exploratory testing.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Black-box Testing'), RoadmapSkill(id: 'template_skill_1', skillName: 'Boundary Value Analysis'), RoadmapSkill(id: 'template_skill_2', skillName: 'Regression Testing'), RoadmapSkill(id: 'template_skill_3', skillName: 'Exploratory Testing')],
      ),
      const RoadmapPhase(
        id: 'sqa_ph3',
        roadmapId: 'sqa_template',
        phaseNumber: 3,
        phaseTitle: 'Programming for Automation',
        phaseDescription: 'Master basic programming (Python or JavaScript) focused on scripting, loops, data structures, and file operations.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Python'), RoadmapSkill(id: 'template_skill_1', skillName: 'Automation Scripting'), RoadmapSkill(id: 'template_skill_2', skillName: 'JSON Parsing'), RoadmapSkill(id: 'template_skill_3', skillName: 'Requests Module')],
      ),
      const RoadmapPhase(
        id: 'sqa_ph4',
        roadmapId: 'sqa_template',
        phaseNumber: 4,
        phaseTitle: 'UI Automation with Selenium & Pytest',
        phaseDescription: 'Automate web applications using Selenium WebDriver, Pytest assertions, HTML reports, and the Page Object Model (POM).',
        estimatedWeeks: 4,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Selenium WebDriver'), RoadmapSkill(id: 'template_skill_1', skillName: 'Pytest'), RoadmapSkill(id: 'template_skill_2', skillName: 'POM'), RoadmapSkill(id: 'template_skill_3', skillName: 'Test Reports')],
      ),
      const RoadmapPhase(
        id: 'sqa_ph5',
        roadmapId: 'sqa_template',
        phaseNumber: 5,
        phaseTitle: 'API Testing & Performance Testing',
        phaseDescription: 'Test REST APIs with Postman. Automate performance and load tests using JMeter or k6 tools.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Postman'), RoadmapSkill(id: 'template_skill_1', skillName: 'API Automation'), RoadmapSkill(id: 'template_skill_2', skillName: 'JMeter'), RoadmapSkill(id: 'template_skill_3', skillName: 'Load Testing')],
      ),
      const RoadmapPhase(
        id: 'sqa_ph6',
        roadmapId: 'sqa_template',
        phaseNumber: 6,
        phaseTitle: 'CI/CD Integration & Portfolio Creation',
        phaseDescription: 'Integrate automated tests in GitHub Actions pipelines. Package your work into a solid QA portfolio on GitHub.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'GitHub Actions'), RoadmapSkill(id: 'template_skill_1', skillName: 'CI/CD Pipelines'), RoadmapSkill(id: 'template_skill_2', skillName: 'Test Coverage'), RoadmapSkill(id: 'template_skill_3', skillName: 'QA Portfolio')],
      ),
    ],
  );

  static final CareerRoadmap _defaultTemplate = CareerRoadmap(
    id: 'default_template',
    careerName: 'Software Engineer',
    description: 'Master general software engineering, computer science fundamentals, and full-stack system design.',
    estimatedDuration: '10-12 months',
    iconName: 'code',
    totalPhases: 6,
    completedPhases: 0,
    overallCompletionPercentage: 0,
    phases: [
      const RoadmapPhase(
        id: 'def_ph1',
        roadmapId: 'default_template',
        phaseNumber: 1,
        phaseTitle: 'Programming & Data Structures',
        phaseDescription: 'Learn Python, Java, or C++ and understand core data structures like arrays, lists, maps, stacks, and queues.',
        estimatedWeeks: 4,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Python/Java/C++'), RoadmapSkill(id: 'template_skill_1', skillName: 'OOP'), RoadmapSkill(id: 'template_skill_2', skillName: 'Data Structures'), RoadmapSkill(id: 'template_skill_3', skillName: 'Git')],
      ),
      const RoadmapPhase(
        id: 'def_ph2',
        roadmapId: 'default_template',
        phaseNumber: 2,
        phaseTitle: 'Algorithms & Problem Solving',
        phaseDescription: 'Master sorting, binary search, recursion, graph traversal, and dynamic programming algorithms.',
        estimatedWeeks: 4,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Algorithms'), RoadmapSkill(id: 'template_skill_1', skillName: 'Complexity Analysis (Big O)'), RoadmapSkill(id: 'template_skill_2', skillName: 'LeetCode Practice')],
      ),
      const RoadmapPhase(
        id: 'def_ph3',
        roadmapId: 'default_template',
        phaseNumber: 3,
        phaseTitle: 'Databases & System Architecture',
        phaseDescription: 'Design SQL/NoSQL schemas, understand transactions, database indexing, and write complex queries.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'SQL'), RoadmapSkill(id: 'template_skill_1', skillName: 'PostgreSQL'), RoadmapSkill(id: 'template_skill_2', skillName: 'NoSQL'), RoadmapSkill(id: 'template_skill_3', skillName: 'Database Design')],
      ),
      const RoadmapPhase(
        id: 'def_ph4',
        roadmapId: 'default_template',
        phaseNumber: 4,
        phaseTitle: 'Web Development & REST APIs',
        phaseDescription: 'Build server-side systems and REST endpoints using Node.js, Express, or Django. Implement auth (JWT).',
        estimatedWeeks: 4,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Node.js/Django'), RoadmapSkill(id: 'template_skill_1', skillName: 'REST APIs'), RoadmapSkill(id: 'template_skill_2', skillName: 'JWT Auth'), RoadmapSkill(id: 'template_skill_3', skillName: 'HTTP Protocol')],
      ),
      const RoadmapPhase(
        id: 'def_ph5',
        roadmapId: 'default_template',
        phaseNumber: 5,
        phaseTitle: 'System Design & Scalability',
        phaseDescription: 'Design architectures for large-scale systems, load balancers, caching strategies, and microservices.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'System Design'), RoadmapSkill(id: 'template_skill_1', skillName: 'Caching (Redis)'), RoadmapSkill(id: 'template_skill_2', skillName: 'Load Balancers'), RoadmapSkill(id: 'template_skill_3', skillName: 'Microservices')],
      ),
      const RoadmapPhase(
        id: 'def_ph6',
        roadmapId: 'default_template',
        phaseNumber: 6,
        phaseTitle: 'DevOps, Containers & Cloud',
        phaseDescription: 'Containerize applications with Docker, set up CI/CD with GitHub Actions, and deploy to AWS/GCP.',
        estimatedWeeks: 3,
        completionPercentage: 0,
        keySkills: [RoadmapSkill(id: 'template_skill_0', skillName: 'Docker'), RoadmapSkill(id: 'template_skill_1', skillName: 'Kubernetes'), RoadmapSkill(id: 'template_skill_2', skillName: 'CI/CD Pipelines'), RoadmapSkill(id: 'template_skill_3', skillName: 'AWS/GCP')],
      ),
    ],
  );
}

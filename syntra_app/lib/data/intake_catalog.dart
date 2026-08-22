import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';

class LearningGoalSpec {
  const LearningGoalSpec({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class EducationLevelSpec {
  const EducationLevelSpec({
    required this.id,
    required this.label,
    required this.tagline,
    required this.accent,
    required this.accentSecondary,
    required this.showExamBoard,
    required this.customBoard,
    required this.boards,
    required this.depths,
    required this.recommendedDepth,
    required this.subjects,
    required this.goals,
  });

  final String id;
  final String label;
  final String tagline;
  final Color accent;
  final Color accentSecondary;
  final bool showExamBoard;
  final bool customBoard;
  final List<String> boards;
  final List<String> depths;
  final String recommendedDepth;
  final List<String> subjects;
  final List<LearningGoalSpec> goals;
}

abstract final class IntakeCatalog {
  static const understand = LearningGoalSpec(
    id: 'understand',
    label: 'Understand a concept',
    description: 'Build a clean mental model from first principles.',
  );
  static const exam = LearningGoalSpec(
    id: 'exam',
    label: 'Prepare for an exam',
    description: 'Structure revision around what the paper actually rewards.',
  );
  static const scratch = LearningGoalSpec(
    id: 'scratch',
    label: 'Learn from scratch',
    description: 'Start at the foundations and climb with no assumed fluency.',
  );
  static const problems = LearningGoalSpec(
    id: 'problems',
    label: 'Solve problems',
    description: 'Worked examples, methods, and transfer to unseen questions.',
  );
  static const review = LearningGoalSpec(
    id: 'review',
    label: 'Review a topic',
    description: 'Tighten what you already know and close the gaps.',
  );
  static const advanced = LearningGoalSpec(
    id: 'advanced',
    label: 'Develop advanced understanding',
    description: 'Go past the syllabus into depth, proof, and synthesis.',
  );

  static const customSubject = 'Custom';

  static const schoolCore = [
    'Mathematics',
    'Science',
    'English',
    'History',
    'Geography',
    'Computing',
    'Art',
  ];

  static const gcseSubjects = [
    'Mathematics',
    'English Language',
    'English Literature',
    'Combined Science',
    'Biology',
    'Chemistry',
    'Physics',
    'History',
    'Geography',
    'Computer Science',
    'French',
    'Spanish',
    'Business',
    'Psychology',
    'Religious Studies',
  ];

  static const aLevelSubjects = [
    'Mathematics',
    'Further Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Economics',
    'History',
    'English Literature',
    'Psychology',
    'Politics',
    'Geography',
    'Philosophy',
  ];

  static const undergraduateSubjects = [
    'Computer Science',
    'Physics',
    'Mathematics',
    'Engineering',
    'Biology',
    'Chemistry',
    'Economics',
    'Psychology',
    'History',
    'Philosophy',
    'Medicine',
    'Law',
    'Business',
  ];

  static const postgraduateSubjects = [
    'Computer Science',
    'Machine Learning',
    'Data Science',
    'Physics',
    'Mathematics',
    'Biology',
    'Chemistry',
    'Economics',
    'Public Policy',
    'Law',
  ];

  static const professionalSubjects = [
    'Software Engineering',
    'Data Analysis',
    'Product Management',
    'Finance',
    'Leadership',
    'Communication',
    'Cybersecurity',
    'Marketing',
  ];

  static final levels = <EducationLevelSpec>[
    EducationLevelSpec(
      id: 'Beginner',
      label: 'Beginner',
      tagline: 'First principles, no assumed fluency',
      accent: SyntraPalette.beginner,
      accentSecondary: Color(0xFFF3C7B0),
      showExamBoard: false,
      customBoard: false,
      boards: [],
      depths: ['Introductory'],
      recommendedDepth: 'Introductory',
      subjects: schoolCore,
      goals: [understand, scratch, review, problems],
    ),
    EducationLevelSpec(
      id: 'Primary',
      label: 'Primary',
      tagline: 'Curious, concrete, classroom-ready',
      accent: SyntraPalette.primary,
      accentSecondary: Color(0xFFB7E0C9),
      showExamBoard: false,
      customBoard: false,
      boards: [],
      depths: ['Introductory'],
      recommendedDepth: 'Introductory',
      subjects: schoolCore,
      goals: [understand, scratch, review, exam],
    ),
    EducationLevelSpec(
      id: 'GCSE',
      label: 'GCSE',
      tagline: 'Exam-ready structure and marks',
      accent: SyntraPalette.gcse,
      accentSecondary: Color(0xFFF3C7B0),
      showExamBoard: true,
      customBoard: false,
      boards: ['AQA', 'Edexcel', 'OCR', 'WJEC', 'Cambridge'],
      depths: ['Introductory', 'GCSE'],
      recommendedDepth: 'GCSE',
      subjects: gcseSubjects,
      goals: [exam, understand, problems, review, scratch],
    ),
    EducationLevelSpec(
      id: 'A-Level',
      label: 'A-Level',
      tagline: 'Depth, methods, and stretch',
      accent: SyntraPalette.aLevel,
      accentSecondary: Color(0xFF2A9D8F),
      showExamBoard: true,
      customBoard: false,
      boards: ['AQA', 'Edexcel', 'OCR', 'Cambridge'],
      depths: ['GCSE', 'A-Level', 'Undergraduate'],
      recommendedDepth: 'A-Level',
      subjects: aLevelSubjects,
      goals: [exam, understand, problems, advanced, review, scratch],
    ),
    EducationLevelSpec(
      id: 'Undergraduate',
      label: 'Undergraduate',
      tagline: 'University rigor without the fog',
      accent: SyntraPalette.undergraduate,
      accentSecondary: Color(0xFFF3C7B0),
      showExamBoard: false,
      customBoard: false,
      boards: [],
      depths: ['A-Level', 'Undergraduate', 'Advanced'],
      recommendedDepth: 'Undergraduate',
      subjects: undergraduateSubjects,
      goals: [understand, problems, advanced, exam, review, scratch],
    ),
    EducationLevelSpec(
      id: 'Postgraduate',
      label: 'Postgraduate',
      tagline: 'Research depth and synthesis',
      accent: SyntraPalette.postgraduate,
      accentSecondary: Color(0xFFF3C7B0),
      showExamBoard: false,
      customBoard: false,
      boards: [],
      depths: ['Undergraduate', 'Advanced'],
      recommendedDepth: 'Advanced',
      subjects: postgraduateSubjects,
      goals: [advanced, understand, review, problems],
    ),
    EducationLevelSpec(
      id: 'Professional',
      label: 'Professional',
      tagline: 'Applied, sharp, on the clock',
      accent: SyntraPalette.professional,
      accentSecondary: Color(0xFFB7E0C9),
      showExamBoard: false,
      customBoard: false,
      boards: [],
      depths: ['Introductory', 'Advanced'],
      recommendedDepth: 'Advanced',
      subjects: professionalSubjects,
      goals: [problems, understand, advanced, scratch, review],
    ),
    EducationLevelSpec(
      id: 'Other',
      label: 'Other',
      tagline: 'Your own level, your own rules',
      accent: SyntraPalette.other,
      accentSecondary: Color(0xFFF3C7B0),
      showExamBoard: false,
      customBoard: true,
      boards: [],
      depths: ['Introductory', 'GCSE', 'A-Level', 'Undergraduate', 'Advanced'],
      recommendedDepth: 'Introductory',
      subjects: unique([
        ...schoolCore,
        ...gcseSubjects,
        ...aLevelSubjects,
        ...undergraduateSubjects,
      ]),
      goals: [understand, exam, scratch, problems, review, advanced],
    ),
  ];

  static List<String> unique(Iterable<String> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item)) item,
    ];
  }

  static EducationLevelSpec levelById(String id) {
    return levels.firstWhere(
      (level) => level.id == id,
      orElse: () => levels.last,
    );
  }

  static List<String> subjectsFor(EducationLevelSpec level) {
    return unique([...level.subjects, customSubject]);
  }

  static List<String> topicsFor({
    required String levelId,
    required String subject,
  }) {
    if (subject == customSubject || subject.isEmpty) return const [];
    final byLevel = _topics[subject];
    if (byLevel == null) return unique(_genericTopics);
    return unique(byLevel[levelId] ?? byLevel['default'] ?? _genericTopics);
  }

  static const _genericTopics = [
    'Foundations',
    'Core ideas',
    'Worked examples',
    'Applications',
  ];

  static const _topics = <String, Map<String, List<String>>>{
    'Mathematics': {
      'default': ['Algebra', 'Geometry', 'Statistics', 'Number', 'Ratio'],
      'GCSE': [
        'Algebra',
        'Trigonometry',
        'Quadratic equations',
        'Probability',
        'Graphs',
        'Ratio and proportion',
      ],
      'A-Level': [
        'Calculus',
        'Trigonometry',
        'Exponentials and logarithms',
        'Sequences and series',
        'Mechanics',
        'Statistics',
      ],
      'Undergraduate': [
        'Linear algebra',
        'Real analysis',
        'Ordinary differential equations',
        'Probability theory',
        'Abstract algebra',
      ],
      'Postgraduate': [
        'Measure theory',
        'Functional analysis',
        'Stochastic processes',
        'Algebraic topology',
      ],
    },
    'Further Mathematics': {
      'default': [
        'Complex numbers',
        'Matrices',
        'Further calculus',
        'Further mechanics',
        'Decision mathematics',
      ],
    },
    'Physics': {
      'default': ['Forces', 'Energy', 'Waves', 'Electricity', 'Magnetism'],
      'GCSE': [
        'Energy stores and transfers',
        'Electricity',
        'Particle model of matter',
        'Atomic structure',
        'Forces and motion',
        'Waves',
      ],
      'A-Level': [
        'Quantum physics',
        'Particle physics',
        'Simple harmonic motion',
        'Electric fields',
        'Magnetic fields',
        'Thermal physics',
        'Nuclear physics',
      ],
      'Undergraduate': [
        'Classical mechanics',
        'Electromagnetism',
        'Quantum mechanics',
        'Statistical mechanics',
        'Special relativity',
      ],
      'Postgraduate': [
        'Quantum field theory',
        'General relativity',
        'Condensed matter',
        'Many-body physics',
      ],
    },
    'Chemistry': {
      'default': [
        'Atomic structure',
        'Bonding',
        'Organic chemistry',
        'Rates of reaction',
        'Equilibria',
      ],
      'A-Level': [
        'Organic mechanisms',
        'Energetics',
        'Redox and electrodes',
        'Transition metals',
        'Spectroscopy',
      ],
      'Undergraduate': [
        'Physical chemistry',
        'Inorganic chemistry',
        'Organic synthesis',
        'Quantum chemistry',
      ],
    },
    'Biology': {
      'default': [
        'Cell biology',
        'Organisation',
        'Infection and response',
        'Bioenergetics',
        'Ecology',
      ],
      'A-Level': [
        'Biological molecules',
        'Cells',
        'Exchange and transport',
        'Genetics',
        'Energy transfers',
        'Ecosystems',
      ],
      'Undergraduate': [
        'Molecular biology',
        'Genetics',
        'Physiology',
        'Evolution',
        'Immunology',
      ],
    },
    'Combined Science': {
      'default': [
        'Cell biology',
        'Atomic structure',
        'Energy',
        'Chemical changes',
        'Forces',
        'Waves',
      ],
    },
    'Science': {
      'default': [
        'Living things',
        'Materials',
        'Forces',
        'Earth and space',
        'Electricity',
      ],
    },
    'Computer Science': {
      'default': [
        'Algorithms',
        'Programming',
        'Data structures',
        'Computer systems',
        'Networks',
      ],
      'GCSE': [
        'Algorithms',
        'Programming fundamentals',
        'Boolean logic',
        'Computer systems',
        'Networks',
        'Cyber security',
      ],
      'A-Level': [
        'Data structures',
        'Object-oriented programming',
        'Databases',
        'Theory of computation',
        'Networking',
      ],
      'Undergraduate': [
        'Algorithms and complexity',
        'Operating systems',
        'Compilers',
        'Machine learning',
        'Distributed systems',
      ],
    },
    'Computing': {
      'default': [
        'How computers work',
        'Scratch and logic',
        'The internet',
        'Digital safety',
      ],
    },
    'Machine Learning': {
      'default': [
        'Supervised learning',
        'Neural networks',
        'Optimisation',
        'Generalisation',
        'Representation learning',
      ],
    },
    'Data Science': {
      'default': [
        'Exploratory analysis',
        'Statistical inference',
        'Feature engineering',
        'Causal thinking',
        'Model evaluation',
      ],
    },
    'Software Engineering': {
      'default': [
        'System design',
        'Testing strategy',
        'APIs',
        'Concurrency',
        'Reliability',
      ],
    },
    'Data Analysis': {
      'default': [
        'Cleaning data',
        'Visualisation',
        'SQL thinking',
        'Metrics',
        'Experimentation',
      ],
    },
    'Economics': {
      'default': [
        'Supply and demand',
        'Market structures',
        'Macroeconomic policy',
        'Elasticity',
        'Externalities',
      ],
    },
    'History': {
      'default': [
        'Causes of conflict',
        'Political change',
        'Source analysis',
        'Interpretations',
      ],
    },
    'English Literature': {
      'default': [
        'Tragedy',
        'Poetry analysis',
        'Narrative voice',
        'Context and criticism',
      ],
    },
    'English Language': {
      'default': [
        'Language analysis',
        'Creative writing',
        'Viewpoint writing',
        'Spoken language',
      ],
    },
    'English': {
      'default': ['Reading', 'Writing', 'Grammar', 'Storytelling'],
    },
    'Psychology': {
      'default': [
        'Memory',
        'Attachment',
        'Social influence',
        'Psychopathology',
        'Research methods',
      ],
    },
    'Philosophy': {
      'default': [
        'Epistemology',
        'Ethics',
        'Metaphysics',
        'Philosophy of mind',
      ],
    },
    'Law': {
      'default': [
        'Criminal law',
        'Contract',
        'Tort',
        'Public law',
        'Legal reasoning',
      ],
    },
    'Engineering': {
      'default': [
        'Statics',
        'Dynamics',
        'Thermodynamics',
        'Circuits',
        'Materials',
      ],
    },
    'Medicine': {
      'default': [
        'Anatomy',
        'Physiology',
        'Pathology',
        'Pharmacology',
        'Clinical reasoning',
      ],
    },
    'Business': {
      'default': [
        'Marketing mix',
        'Finance',
        'Operations',
        'Strategy',
        'People and organisations',
      ],
    },
    'Geography': {
      'default': [
        'Physical landscapes',
        'Climate',
        'Urban change',
        'Resource management',
      ],
    },
    'Politics': {
      'default': [
        'UK government',
        'Political ideologies',
        'Comparative politics',
        'Political ideas',
      ],
    },
    'Product Management': {
      'default': [
        'Discovery',
        'Roadmapping',
        'Metrics',
        'Stakeholder alignment',
      ],
    },
    'Finance': {
      'default': [
        'Financial statements',
        'Valuation',
        'Risk',
        'Capital markets',
      ],
    },
    'Leadership': {
      'default': [
        'Decision making',
        'Feedback',
        'Strategy execution',
        'Team design',
      ],
    },
    'Communication': {
      'default': [
        'Narrative structure',
        'Persuasion',
        'Executive updates',
        'Difficult conversations',
      ],
    },
    'Cybersecurity': {
      'default': [
        'Threat modelling',
        'Identity and access',
        'Network security',
        'Incident response',
      ],
    },
    'Marketing': {
      'default': [
        'Positioning',
        'Growth loops',
        'Brand systems',
        'Channel strategy',
      ],
    },
    'Public Policy': {
      'default': [
        'Policy design',
        'Evidence and evaluation',
        'Institutions',
        'Political economy',
      ],
    },
  };
}

import '../database/tables/curriculum_subjects.dart';

// ============================================================
// Curriculum Level Definitions
// ============================================================

/// A named level within a curriculum, with its ordered list of valid subjects.
class CurriculumLevel {
  const CurriculumLevel({
    required this.index,
    required this.label,
    required this.subjects,
  });

  /// 0-based index — used as the level identifier stored in [SchoolConfig.enabledLevels].
  final int index;

  /// Human-readable name shown in the UI.
  final String label;

  /// Ordered list of subjects valid for this level.
  final List<int> subjects;
}

// ─────────────────────────────────────────────────────────────────────────────
// CBC Level Definitions
// ─────────────────────────────────────────────────────────────────────────────

/// All CBC levels, in curriculum order.
const List<CurriculumLevel> kCbcLevels = [
  // NOTE: Pre-Primary (PP1–PP2, index 0) intentionally excluded.
  // All other indices kept as-is — they are stored in settings.data JSON.
  CurriculumLevel(
    index: 1,
    label: 'Lower Primary (Grades 1–3)',
    subjects: [
      1, // literacy
      2, // kiswahiliLanguage
      3, // englishLanguage
      4, // mathematicsLowerPrimary
      5, // environmentalActivities
      6, // hygieneAndNutrition
      7, // creCreativeArtsLowerPrimary
      8, // physicalAndHealthEducationLowerPrimary
      9, // religiousEducationCreLowerPrimary
      10, // religiousEducationIreLowerPrimary
      11, // religiousEducationHreLowerPrimary
      12, // indigenousLanguageLowerPrimary
      13, // kenyaSignLanguageLowerPrimary
    ],
  ),
  CurriculumLevel(
    index: 2,
    label: 'Upper Primary (Grades 4–6)',
    subjects: [
      14, // englishUpperPrimary
      15, // kiswahiliUpperPrimary
      16, // mathematicsUpperPrimary
      17, // integratedScienceUpperPrimary
      18, // socialStudiesUpperPrimary
      19, // creativeArtsAndCraftUpperPrimary
      20, // physicalAndHealthEducationUpperPrimary
      21, // religiousEducationCreUpperPrimary
      22, // religiousEducationIreUpperPrimary
      23, // religiousEducationHreUpperPrimary
      24, // agricultureUpperPrimary
      25, // homeScience
      26, // computerScienceUpperPrimary
      27, // foreignLanguageFrenchUpperPrimary
      28, // foreignLanguageGermanUpperPrimary
      29, // foreignLanguageArabicUpperPrimary
      30, // foreignLanguageMandarinUpperPrimary
      31, // kenyaSignLanguageUpperPrimary
    ],
  ),
  CurriculumLevel(
    index: 3,
    label: 'Junior Secondary (Grades 7–9)',
    subjects: [
      32, // englishJuniorSecondary
      33, // kiswahiliJuniorSecondary
      34, // mathematicsJuniorSecondary
      35, // integratedScienceJuniorSecondary
      36, // healthEducation
      37, // preTechnicalAndPreCareerEducation
      38, // socialStudiesJuniorSecondary
      39, // religiousEducationCreJuniorSecondary
      40, // religiousEducationIreJuniorSecondary
      41, // religiousEducationHreJuniorSecondary
      42, // businessStudiesJuniorSecondary
      43, // agricultureJuniorSecondary
      44, // lifeSkillsJuniorSecondary
      45, // visualArtsJuniorSecondary
      46, // performingArtsJuniorSecondary
      47, // physicalAndHealthEducationJuniorSecondary
      48, // computerScienceJuniorSecondary
      49, // homeEconomicsJuniorSecondary
      50, // foreignLanguageFrenchJuniorSecondary
      51, // foreignLanguageGermanJuniorSecondary
      52, // foreignLanguageArabicJuniorSecondary
      53, // foreignLanguageMandarinJuniorSecondary
      54, // kenyaSignLanguageJuniorSecondary
    ],
  ),
  CurriculumLevel(
    index: 4,
    label: 'Senior Secondary — STEM (Grades 10–12)',
    subjects: [
      // Core (all pathways)
      55, // englishSeniorSecondary
      56, // kiswahiliSeniorSecondary
      57, // communityService
      58, // physicalEducationAndSportsSeniorSecondary
      // STEM-specific
      59, // mathematicsStem
      60, // physicsStem
      61, // chemistryStem
      62, // biologyStem
      63, // computerScienceStem
      64, // agricultureStem
      65, // aviateTechnology
      66, // marineAndFisheries
      67, // buildingAndConstruction
      68, // electricity
      69, // metalWork
      70, // woodWork
      71, // drawingAndDesign
      72, // clothingAndTextiles
      73, // powerMechanics
      99, // additionalMathematicsSeniorSecondary
      100, // informaticsAndDigitalLiteracy
      101, // environmentalEducation
      103, // tourismAndHospitality
    ],
  ),
  CurriculumLevel(
    index: 5,
    label: 'Senior Secondary — Social Sciences (Grades 10–12)',
    subjects: [
      // Core (all pathways)
      55, // englishSeniorSecondary
      56, // kiswahiliSeniorSecondary
      57, // communityService
      58, // physicalEducationAndSportsSeniorSecondary
      // Social Sciences-specific
      74, // mathematicsSocialSciences
      75, // geographySocialSciences
      76, // historyAndCitizenshipSocialSciences
      77, // businessStudiesSocialSciences
      78, // economicsSocialSciences
      79, // religiousEducationCreSeniorSecondary
      80, // religiousEducationIreSeniorSecondary
      81, // religiousEducationHreSeniorSecondary
      82, // legalStudies
      83, // foreignLanguageFrenchSeniorSecondary
      84, // foreignLanguageGermanSeniorSecondary
      85, // foreignLanguageArabicSeniorSecondary
      86, // foreignLanguageMandarinSeniorSecondary
      87, // foreignLanguageJapaneseSeniorSecondary
      88, // foreignLanguageSpanishSeniorSecondary
      89, // indigenousLanguagesSeniorSecondary
      99, // additionalMathematicsSeniorSecondary
      100, // informaticsAndDigitalLiteracy
      101, // environmentalEducation
      102, // landscapingAndFlora
      103, // tourismAndHospitality
    ],
  ),
  CurriculumLevel(
    index: 6,
    label: 'Senior Secondary — Arts & Sports Science (Grades 10–12)',
    subjects: [
      // Core (all pathways)
      55, // englishSeniorSecondary
      56, // kiswahiliSeniorSecondary
      57, // communityService
      58, // physicalEducationAndSportsSeniorSecondary
      // Arts & Sports-specific
      90, // generalMathematics
      91, // visualArtsAndDesign
      92, // performingArts
      93, // musicSeniorSecondary
      94, // theatreArts
      95, // danceAndMovement
      96, // filmsAndAnimation
      97, // sportsScienceAndNutrition
      98, // homeScienceSeniorSecondary
      99, // additionalMathematicsSeniorSecondary
      100, // informaticsAndDigitalLiteracy
      101, // environmentalEducation
      102, // landscapingAndFlora
      103, // tourismAndHospitality
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// 8-4-4 Level Definitions
// ─────────────────────────────────────────────────────────────────────────────

/// All 8-4-4 levels, in curriculum order.
const List<CurriculumLevel> k844Levels = [
  CurriculumLevel(
    index: 0,
    label: 'Lower Primary (Standards 1–3)',
    subjects: [
      0, // englishPrimary
      1, // kiswahiliPrimary
      2, // mathematicsPrimary
      3, // scienceAndTechnology
      4, // socialStudiesGeographyHistoryCivics
      5, // creChristianReligiousEducationPrimary
      6, // ireIslamicReligiousEducationPrimary
      7, // hinduReligiousEducationPrimary
      8, // creativePrimaryArtsAndCraft
      9, // musicPrimary
      10, // physicalEducationPrimary
      11, // homeSciencePrimary
      12, // agriculturePrimary
    ],
  ),
  CurriculumLevel(
    index: 1,
    label: 'Upper Primary (Standards 4–8)',
    subjects: [
      0, // englishPrimary
      1, // kiswahiliPrimary
      2, // mathematicsPrimary
      3, // scienceAndTechnology
      4, // socialStudiesGeographyHistoryCivics
      5, // creChristianReligiousEducationPrimary
      6, // ireIslamicReligiousEducationPrimary
      7, // hinduReligiousEducationPrimary
      8, // creativePrimaryArtsAndCraft
      9, // musicPrimary
      10, // physicalEducationPrimary
      11, // homeSciencePrimary
      12, // agriculturePrimary
    ],
  ),
  CurriculumLevel(
    index: 2,
    label: 'Secondary — Forms 1–2',
    subjects: [
      13, // englishSecondary
      14, // kiswahiliSecondary
      15, // mathematicsSecondary
      16, // biologyCoreSecondary
      17, // physicsSecondary
      18, // chemistrySecondary
      19, // historyAndGovernment
      20, // geographySecondary
      21, // creChristianReligiousEducationSecondary
      22, // ireIslamicReligiousEducationSecondary
      23, // hinduReligiousEducationSecondary
      24, // additionalMathematics
      25, // commerce
      26, // economics
      27, // accounting
      28, // businessStudiesSecondary
      29, // officeManagementAndOfficeAdministration
      30, // computerStudies
      31, // agricultureSecondary
      32, // homeScienceSecondary
      33, // buildingAndConstructionSecondary
      34, // electricitySecondary
      35, // woodworkSecondary
      36, // metalworkSecondary
      37, // drawingAndDesignSecondary
      38, // clothingAndTextilesSecondary
      39, // powerMechanicsSecondary
      40, // aviationSecondary
      41, // artAndDesign
      42, // musicSecondary
      43, // dancingAndDramaSecondary
      44, // frenchSecondary
      45, // germanSecondary
      46, // arabicSecondary
      47, // kenyaSignLanguageSecondary
      48, // socialEthicsAndDevelopment
      49, // divinity
    ],
  ),
  CurriculumLevel(
    index: 3,
    label: 'Secondary — Forms 3–4',
    subjects: [
      13, // englishSecondary
      14, // kiswahiliSecondary
      15, // mathematicsSecondary
      16, // biologyCoreSecondary
      17, // physicsSecondary
      18, // chemistrySecondary
      19, // historyAndGovernment
      20, // geographySecondary
      21, // creChristianReligiousEducationSecondary
      22, // ireIslamicReligiousEducationSecondary
      23, // hinduReligiousEducationSecondary
      24, // additionalMathematics
      25, // commerce
      26, // economics
      27, // accounting
      28, // businessStudiesSecondary
      29, // officeManagementAndOfficeAdministration
      30, // computerStudies
      31, // agricultureSecondary
      32, // homeScienceSecondary
      33, // buildingAndConstructionSecondary
      34, // electricitySecondary
      35, // woodworkSecondary
      36, // metalworkSecondary
      37, // drawingAndDesignSecondary
      38, // clothingAndTextilesSecondary
      39, // powerMechanicsSecondary
      40, // aviationSecondary
      41, // artAndDesign
      42, // musicSecondary
      43, // dancingAndDramaSecondary
      44, // frenchSecondary
      45, // germanSecondary
      46, // arabicSecondary
      47, // kenyaSignLanguageSecondary
      48, // socialEthicsAndDevelopment
      49, // divinity
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helper: look up a level list for a curriculum type
// ─────────────────────────────────────────────────────────────────────────────

List<CurriculumLevel> levelsFor(CurriculumType curriculum) =>
    switch (curriculum) {
      CurriculumType.cbc => kCbcLevels,
      CurriculumType.eightFourFour => k844Levels,
    };

/// Returns the human-readable label for a subject index given a curriculum.
@Deprecated(
  'Use subjects table name instead — subject IDs are now real auto-increment values, not enum indices',
)
String subjectLabel(CurriculumType curriculum, int subjectIndex) {
  switch (curriculum) {
    case CurriculumType.cbc:
      try {
        return CbcSubject.values
            .firstWhere((e) => e.index_ == subjectIndex)
            .label;
      } catch (_) {
        return 'Unknown ($subjectIndex)';
      }
    case CurriculumType.eightFourFour:
      try {
        return EightFourFourSubject.values
            .firstWhere((e) => e.index_ == subjectIndex)
            .label;
      } catch (_) {
        return 'Unknown ($subjectIndex)';
      }
  }
}

import 'package:drift/drift.dart';

// ============================================================
// Curriculum Type
// ============================================================

/// The national curriculum system a school follows.
enum CurriculumType {
  cbc(0),
  eightFourFour(1);

  const CurriculumType(this.index_);
  final int index_;
}

class CurriculumTypeConverter extends TypeConverter<CurriculumType, int> {
  const CurriculumTypeConverter();
  @override
  CurriculumType fromSql(int fromDb) =>
      CurriculumType.values.firstWhere((e) => e.index_ == fromDb);
  @override
  int toSql(CurriculumType value) => value.index_;
}

// ============================================================
// CBC Subject Enum
// Covers PP1–PP2, Lower Primary (Grades 1–3), Upper Primary (Grades 4–6),
// Junior Secondary (Grades 7–9), and Senior Secondary (Grades 10–12)
// as published by KICD.
// ============================================================

enum CbcSubject {
  // ── Pre-Primary (PP1–PP2) ──
  prePrimaryActivities(0),

  // ── Lower Primary (Grades 1–3) ──
  literacy(1),
  kiswahiliLanguage(2),
  englishLanguage(3),
  mathematicsLowerPrimary(4),
  environmentalActivities(5),
  hygieneAndNutrition(6),
  creCreativeArtsLowerPrimary(7),
  physicalAndHealthEducationLowerPrimary(8),
  religiousEducationCreLowerPrimary(9),
  religiousEducationIreLowerPrimary(10),
  religiousEducationHreLowerPrimary(11),
  indigenousLanguageLowerPrimary(12),
  kenyaSignLanguageLowerPrimary(13),

  // ── Upper Primary (Grades 4–6) ──
  englishUpperPrimary(14),
  kiswahiliUpperPrimary(15),
  mathematicsUpperPrimary(16),
  integratedScienceUpperPrimary(17),
  socialStudiesUpperPrimary(18),
  creativeArtsAndCraftUpperPrimary(19),
  physicalAndHealthEducationUpperPrimary(20),
  religiousEducationCreUpperPrimary(21),
  religiousEducationIreUpperPrimary(22),
  religiousEducationHreUpperPrimary(23),
  agricultureUpperPrimary(24),
  homeScience(25),
  computerScienceUpperPrimary(26),
  foreignLanguageFrenchUpperPrimary(27),
  foreignLanguageGermanUpperPrimary(28),
  foreignLanguageArabicUpperPrimary(29),
  foreignLanguageMandarinUpperPrimary(30),
  kenyaSignLanguageUpperPrimary(31),

  // ── Junior Secondary (Grades 7–9) ──
  englishJuniorSecondary(32),
  kiswahiliJuniorSecondary(33),
  mathematicsJuniorSecondary(34),
  integratedScienceJuniorSecondary(35),
  healthEducation(36),
  preTechnicalAndPreCareerEducation(37),
  socialStudiesJuniorSecondary(38),
  religiousEducationCreJuniorSecondary(39),
  religiousEducationIreJuniorSecondary(40),
  religiousEducationHreJuniorSecondary(41),
  businessStudiesJuniorSecondary(42),
  agricultureJuniorSecondary(43),
  lifeSkillsJuniorSecondary(44),
  visualArtsJuniorSecondary(45),
  performingArtsJuniorSecondary(46),
  physicalAndHealthEducationJuniorSecondary(47),
  computerScienceJuniorSecondary(48),
  homeEconomicsJuniorSecondary(49),
  foreignLanguageFrenchJuniorSecondary(50),
  foreignLanguageGermanJuniorSecondary(51),
  foreignLanguageArabicJuniorSecondary(52),
  foreignLanguageMandarinJuniorSecondary(53),
  kenyaSignLanguageJuniorSecondary(54),

  // ── Senior Secondary — Core (Grades 10–12, all pathways) ──
  englishSeniorSecondary(55),
  kiswahiliSeniorSecondary(56),
  communityService(57),
  physicalEducationAndSportsSeniorSecondary(58),

  // ── Senior Secondary — STEM Pathway ──
  mathematicsStem(59),
  physicsStem(60),
  chemistryStem(61),
  biologyStem(62),
  computerScienceStem(63),
  agricultureStem(64),
  aviateTechnology(65),
  marineAndFisheries(66),
  buildingAndConstruction(67),
  electricity(68),
  metalWork(69),
  woodWork(70),
  drawingAndDesign(71),
  clothingAndTextiles(72),
  powerMechanics(73),

  // ── Senior Secondary — Social Sciences Pathway ──
  mathematicsSocialSciences(74),
  geographySocialSciences(75),
  historyAndCitizenshipSocialSciences(76),
  businessStudiesSocialSciences(77),
  economicsSocialSciences(78),
  religiousEducationCreSeniorSecondary(79),
  religiousEducationIreSeniorSecondary(80),
  religiousEducationHreSeniorSecondary(81),
  legalStudies(82),
  foreignLanguageFrenchSeniorSecondary(83),
  foreignLanguageGermanSeniorSecondary(84),
  foreignLanguageArabicSeniorSecondary(85),
  foreignLanguageMandarinSeniorSecondary(86),
  foreignLanguageJapaneseSeniorSecondary(87),
  foreignLanguageSpanishSeniorSecondary(88),
  indigenousLanguagesSeniorSecondary(89),

  // ── Senior Secondary — Arts & Sports Science Pathway ──
  generalMathematics(90),
  visualArtsAndDesign(91),
  performingArts(92),
  musicSeniorSecondary(93),
  theatreArts(94),
  danceAndMovement(95),
  filmsAndAnimation(96),
  sportsScienceAndNutrition(97),
  homeScienceSeniorSecondary(98),

  // ── Senior Secondary — Additional Cross-Pathway Electives ──
  additionalMathematicsSeniorSecondary(99),
  informaticsAndDigitalLiteracy(100),
  environmentalEducation(101),
  landscapingAndFlora(102),
  tourismAndHospitality(103);

  const CbcSubject(this.index_);
  final int index_;

  String get label => switch (this) {
    CbcSubject.prePrimaryActivities => 'Pre-Primary Activities',
    CbcSubject.literacy => 'Literacy',
    CbcSubject.kiswahiliLanguage => 'Kiswahili Language',
    CbcSubject.englishLanguage => 'English Language',
    CbcSubject.mathematicsLowerPrimary => 'Mathematics',
    CbcSubject.environmentalActivities => 'Environmental Activities',
    CbcSubject.hygieneAndNutrition => 'Hygiene and Nutrition',
    CbcSubject.creCreativeArtsLowerPrimary => 'Creative Arts',
    CbcSubject.physicalAndHealthEducationLowerPrimary =>
      'Physical and Health Education',
    CbcSubject.religiousEducationCreLowerPrimary =>
      'Christian Religious Education',
    CbcSubject.religiousEducationIreLowerPrimary =>
      'Islamic Religious Education',
    CbcSubject.religiousEducationHreLowerPrimary => 'Hindu Religious Education',
    CbcSubject.indigenousLanguageLowerPrimary => 'Indigenous Language',
    CbcSubject.kenyaSignLanguageLowerPrimary => 'Kenya Sign Language',
    CbcSubject.englishUpperPrimary => 'English',
    CbcSubject.kiswahiliUpperPrimary => 'Kiswahili',
    CbcSubject.mathematicsUpperPrimary => 'Mathematics',
    CbcSubject.integratedScienceUpperPrimary => 'Integrated Science',
    CbcSubject.socialStudiesUpperPrimary => 'Social Studies',
    CbcSubject.creativeArtsAndCraftUpperPrimary => 'Creative Arts and Craft',
    CbcSubject.physicalAndHealthEducationUpperPrimary =>
      'Physical and Health Education',
    CbcSubject.religiousEducationCreUpperPrimary =>
      'Christian Religious Education',
    CbcSubject.religiousEducationIreUpperPrimary =>
      'Islamic Religious Education',
    CbcSubject.religiousEducationHreUpperPrimary => 'Hindu Religious Education',
    CbcSubject.agricultureUpperPrimary => 'Agriculture',
    CbcSubject.homeScience => 'Home Science',
    CbcSubject.computerScienceUpperPrimary => 'Computer Science',
    CbcSubject.foreignLanguageFrenchUpperPrimary => 'French',
    CbcSubject.foreignLanguageGermanUpperPrimary => 'German',
    CbcSubject.foreignLanguageArabicUpperPrimary => 'Arabic',
    CbcSubject.foreignLanguageMandarinUpperPrimary => 'Mandarin',
    CbcSubject.kenyaSignLanguageUpperPrimary => 'Kenya Sign Language',
    CbcSubject.englishJuniorSecondary => 'English',
    CbcSubject.kiswahiliJuniorSecondary => 'Kiswahili',
    CbcSubject.mathematicsJuniorSecondary => 'Mathematics',
    CbcSubject.integratedScienceJuniorSecondary => 'Integrated Science',
    CbcSubject.healthEducation => 'Health Education',
    CbcSubject.preTechnicalAndPreCareerEducation =>
      'Pre-Technical and Pre-Career Education',
    CbcSubject.socialStudiesJuniorSecondary => 'Social Studies',
    CbcSubject.religiousEducationCreJuniorSecondary =>
      'Christian Religious Education',
    CbcSubject.religiousEducationIreJuniorSecondary =>
      'Islamic Religious Education',
    CbcSubject.religiousEducationHreJuniorSecondary =>
      'Hindu Religious Education',
    CbcSubject.businessStudiesJuniorSecondary => 'Business Studies',
    CbcSubject.agricultureJuniorSecondary => 'Agriculture',
    CbcSubject.lifeSkillsJuniorSecondary => 'Life Skills',
    CbcSubject.visualArtsJuniorSecondary => 'Visual Arts',
    CbcSubject.performingArtsJuniorSecondary => 'Performing Arts',
    CbcSubject.physicalAndHealthEducationJuniorSecondary =>
      'Physical and Health Education',
    CbcSubject.computerScienceJuniorSecondary => 'Computer Science',
    CbcSubject.homeEconomicsJuniorSecondary => 'Home Economics',
    CbcSubject.foreignLanguageFrenchJuniorSecondary => 'French',
    CbcSubject.foreignLanguageGermanJuniorSecondary => 'German',
    CbcSubject.foreignLanguageArabicJuniorSecondary => 'Arabic',
    CbcSubject.foreignLanguageMandarinJuniorSecondary => 'Mandarin',
    CbcSubject.kenyaSignLanguageJuniorSecondary => 'Kenya Sign Language',
    CbcSubject.englishSeniorSecondary => 'English',
    CbcSubject.kiswahiliSeniorSecondary => 'Kiswahili',
    CbcSubject.communityService => 'Community Service',
    CbcSubject.physicalEducationAndSportsSeniorSecondary =>
      'Physical Education and Sports',
    CbcSubject.mathematicsStem => 'Mathematics',
    CbcSubject.physicsStem => 'Physics',
    CbcSubject.chemistryStem => 'Chemistry',
    CbcSubject.biologyStem => 'Biology',
    CbcSubject.computerScienceStem => 'Computer Science',
    CbcSubject.agricultureStem => 'Agriculture',
    CbcSubject.aviateTechnology => 'Aviation Technology',
    CbcSubject.marineAndFisheries => 'Marine and Fisheries',
    CbcSubject.buildingAndConstruction => 'Building and Construction',
    CbcSubject.electricity => 'Electricity',
    CbcSubject.metalWork => 'Metal Work',
    CbcSubject.woodWork => 'Wood Work',
    CbcSubject.drawingAndDesign => 'Drawing and Design',
    CbcSubject.clothingAndTextiles => 'Clothing and Textiles',
    CbcSubject.powerMechanics => 'Power Mechanics',
    CbcSubject.mathematicsSocialSciences => 'Mathematics',
    CbcSubject.geographySocialSciences => 'Geography',
    CbcSubject.historyAndCitizenshipSocialSciences => 'History and Citizenship',
    CbcSubject.businessStudiesSocialSciences => 'Business Studies',
    CbcSubject.economicsSocialSciences => 'Economics',
    CbcSubject.religiousEducationCreSeniorSecondary =>
      'Christian Religious Education',
    CbcSubject.religiousEducationIreSeniorSecondary =>
      'Islamic Religious Education',
    CbcSubject.religiousEducationHreSeniorSecondary =>
      'Hindu Religious Education',
    CbcSubject.legalStudies => 'Legal Studies',
    CbcSubject.foreignLanguageFrenchSeniorSecondary => 'French',
    CbcSubject.foreignLanguageGermanSeniorSecondary => 'German',
    CbcSubject.foreignLanguageArabicSeniorSecondary => 'Arabic',
    CbcSubject.foreignLanguageMandarinSeniorSecondary => 'Mandarin',
    CbcSubject.foreignLanguageJapaneseSeniorSecondary => 'Japanese',
    CbcSubject.foreignLanguageSpanishSeniorSecondary => 'Spanish',
    CbcSubject.indigenousLanguagesSeniorSecondary => 'Indigenous Languages',
    CbcSubject.generalMathematics => 'General Mathematics',
    CbcSubject.visualArtsAndDesign => 'Visual Arts and Design',
    CbcSubject.performingArts => 'Performing Arts',
    CbcSubject.musicSeniorSecondary => 'Music',
    CbcSubject.theatreArts => 'Theatre Arts',
    CbcSubject.danceAndMovement => 'Dance and Movement',
    CbcSubject.filmsAndAnimation => 'Films and Animation',
    CbcSubject.sportsScienceAndNutrition => 'Sports Science and Nutrition',
    CbcSubject.homeScienceSeniorSecondary => 'Home Science',
    CbcSubject.additionalMathematicsSeniorSecondary => 'Additional Mathematics',
    CbcSubject.informaticsAndDigitalLiteracy =>
      'Informatics and Digital Literacy',
    CbcSubject.environmentalEducation => 'Environmental Education',
    CbcSubject.landscapingAndFlora => 'Landscaping and Flora',
    CbcSubject.tourismAndHospitality => 'Tourism and Hospitality',
  };
}

class CbcSubjectConverter extends TypeConverter<CbcSubject, int> {
  const CbcSubjectConverter();
  @override
  CbcSubject fromSql(int fromDb) =>
      CbcSubject.values.firstWhere((e) => e.index_ == fromDb);
  @override
  int toSql(CbcSubject value) => value.index_;
}

// ============================================================
// 8-4-4 Subject Enum
// Covers Standard 1–8 (Primary) and Form 1–4 (Secondary)
// as per the Kenya Institute of Curriculum Development 8-4-4 curriculum.
// ============================================================

enum EightFourFourSubject {
  // ── Primary (Standards 1–8) — Core ──
  englishPrimary(0),
  kiswahiliPrimary(1),
  mathematicsPrimary(2),
  scienceAndTechnology(3),
  socialStudiesGeographyHistoryCivics(4),
  creChristianReligiousEducationPrimary(5),
  ireIslamicReligiousEducationPrimary(6),
  hinduReligiousEducationPrimary(7),

  // ── Primary (Standards 1–8) — Optional / Activity-Based ──
  creativePrimaryArtsAndCraft(8),
  musicPrimary(9),
  physicalEducationPrimary(10),
  homeSciencePrimary(11),
  agriculturePrimary(12),

  // ── Secondary (Forms 1–4) — Compulsory ──
  englishSecondary(13),
  kiswahiliSecondary(14),
  mathematicsSecondary(15),
  biologyCoreSecondary(16),
  physicsSecondary(17),
  chemistrySecondary(18),
  historyAndGovernment(19),
  geographySecondary(20),
  creChristianReligiousEducationSecondary(21),
  ireIslamicReligiousEducationSecondary(22),
  hinduReligiousEducationSecondary(23),

  // ── Secondary — Sciences Cluster Electives ──
  additionalMathematics(24),

  // ── Secondary — Humanities / Commerce Cluster Electives ──
  commerce(25),
  economics(26),
  accounting(27),
  businessStudiesSecondary(28),
  officeManagementAndOfficeAdministration(29),

  // ── Secondary — Technical / Applied Cluster Electives ──
  computerStudies(30),
  agricultureSecondary(31),
  homeScienceSecondary(32),
  buildingAndConstructionSecondary(33),
  electricitySecondary(34),
  woodworkSecondary(35),
  metalworkSecondary(36),
  drawingAndDesignSecondary(37),
  clothingAndTextilesSecondary(38),
  powerMechanicsSecondary(39),
  aviationSecondary(40),

  // ── Secondary — Arts Cluster Electives ──
  artAndDesign(41),
  musicSecondary(42),
  dancingAndDramaSecondary(43),

  // ── Secondary — Languages (Foreign / Optional) ──
  frenchSecondary(44),
  germanSecondary(45),
  arabicSecondary(46),
  kenyaSignLanguageSecondary(47),

  // ── Secondary — Other ──
  socialEthicsAndDevelopment(48),
  divinity(49);

  const EightFourFourSubject(this.index_);
  final int index_;

  String get label => switch (this) {
    EightFourFourSubject.englishPrimary => 'English',
    EightFourFourSubject.kiswahiliPrimary => 'Kiswahili',
    EightFourFourSubject.mathematicsPrimary => 'Mathematics',
    EightFourFourSubject.scienceAndTechnology => 'Science and Technology',
    EightFourFourSubject.socialStudiesGeographyHistoryCivics =>
      'Social Studies / Geography / History & Civics',
    EightFourFourSubject.creChristianReligiousEducationPrimary =>
      'Christian Religious Education',
    EightFourFourSubject.ireIslamicReligiousEducationPrimary =>
      'Islamic Religious Education',
    EightFourFourSubject.hinduReligiousEducationPrimary =>
      'Hindu Religious Education',
    EightFourFourSubject.creativePrimaryArtsAndCraft =>
      'Creative Arts and Craft',
    EightFourFourSubject.musicPrimary => 'Music',
    EightFourFourSubject.physicalEducationPrimary => 'Physical Education',
    EightFourFourSubject.homeSciencePrimary => 'Home Science',
    EightFourFourSubject.agriculturePrimary => 'Agriculture',
    EightFourFourSubject.englishSecondary => 'English',
    EightFourFourSubject.kiswahiliSecondary => 'Kiswahili',
    EightFourFourSubject.mathematicsSecondary => 'Mathematics',
    EightFourFourSubject.biologyCoreSecondary => 'Biology',
    EightFourFourSubject.physicsSecondary => 'Physics',
    EightFourFourSubject.chemistrySecondary => 'Chemistry',
    EightFourFourSubject.historyAndGovernment => 'History and Government',
    EightFourFourSubject.geographySecondary => 'Geography',
    EightFourFourSubject.creChristianReligiousEducationSecondary =>
      'Christian Religious Education',
    EightFourFourSubject.ireIslamicReligiousEducationSecondary =>
      'Islamic Religious Education',
    EightFourFourSubject.hinduReligiousEducationSecondary =>
      'Hindu Religious Education',
    EightFourFourSubject.additionalMathematics => 'Additional Mathematics',
    EightFourFourSubject.commerce => 'Commerce',
    EightFourFourSubject.economics => 'Economics',
    EightFourFourSubject.accounting => 'Accounting',
    EightFourFourSubject.businessStudiesSecondary => 'Business Studies',
    EightFourFourSubject.officeManagementAndOfficeAdministration =>
      'Office Management and Administration',
    EightFourFourSubject.computerStudies => 'Computer Studies',
    EightFourFourSubject.agricultureSecondary => 'Agriculture',
    EightFourFourSubject.homeScienceSecondary => 'Home Science',
    EightFourFourSubject.buildingAndConstructionSecondary =>
      'Building and Construction',
    EightFourFourSubject.electricitySecondary => 'Electricity',
    EightFourFourSubject.woodworkSecondary => 'Woodwork',
    EightFourFourSubject.metalworkSecondary => 'Metalwork',
    EightFourFourSubject.drawingAndDesignSecondary => 'Drawing and Design',
    EightFourFourSubject.clothingAndTextilesSecondary =>
      'Clothing and Textiles',
    EightFourFourSubject.powerMechanicsSecondary => 'Power Mechanics',
    EightFourFourSubject.aviationSecondary => 'Aviation',
    EightFourFourSubject.artAndDesign => 'Art and Design',
    EightFourFourSubject.musicSecondary => 'Music',
    EightFourFourSubject.dancingAndDramaSecondary => 'Dancing and Drama',
    EightFourFourSubject.frenchSecondary => 'French',
    EightFourFourSubject.germanSecondary => 'German',
    EightFourFourSubject.arabicSecondary => 'Arabic',
    EightFourFourSubject.kenyaSignLanguageSecondary => 'Kenya Sign Language',
    EightFourFourSubject.socialEthicsAndDevelopment =>
      'Social Ethics and Development',
    EightFourFourSubject.divinity => 'Divinity',
  };
}

class EightFourFourSubjectConverter
    extends TypeConverter<EightFourFourSubject, int> {
  const EightFourFourSubjectConverter();
  @override
  EightFourFourSubject fromSql(int fromDb) =>
      EightFourFourSubject.values.firstWhere((e) => e.index_ == fromDb);
  @override
  int toSql(EightFourFourSubject value) => value.index_;
}

// ============================================================
// Kenya County Enum
// All 47 counties ordered by official county number (1–47)
// as assigned by the Constitution of Kenya 2010.
// The DB stores the county number (1–47), NOT the Dart index (0–46).
// ============================================================

enum KenyaCounty {
  mombasa(1, 'Mombasa'),
  kwale(2, 'Kwale'),
  kilifi(3, 'Kilifi'),
  tanaRiver(4, 'Tana River'),
  lamu(5, 'Lamu'),
  taitaTaveta(6, 'Taita-Taveta'),
  garissa(7, 'Garissa'),
  wajir(8, 'Wajir'),
  mandera(9, 'Mandera'),
  marsabit(10, 'Marsabit'),
  isiolo(11, 'Isiolo'),
  meru(12, 'Meru'),
  tharakaNithi(13, 'Tharaka-Nithi'),
  embu(14, 'Embu'),
  kitui(15, 'Kitui'),
  machakos(16, 'Machakos'),
  makueni(17, 'Makueni'),
  nyandarua(18, 'Nyandarua'),
  nyeri(19, 'Nyeri'),
  kirinyaga(20, 'Kirinyaga'),
  muranga(21, "Murang'a"),
  kiambu(22, 'Kiambu'),
  turkana(23, 'Turkana'),
  westPokot(24, 'West Pokot'),
  samburu(25, 'Samburu'),
  transNzoia(26, 'Trans-Nzoia'),
  uasinGishu(27, 'Uasin Gishu'),
  elgeyoMarakwet(28, 'Elgeyo-Marakwet'),
  nandi(29, 'Nandi'),
  baringo(30, 'Baringo'),
  laikipia(31, 'Laikipia'),
  nakuru(32, 'Nakuru'),
  narok(33, 'Narok'),
  kajiado(34, 'Kajiado'),
  kericho(35, 'Kericho'),
  bomet(36, 'Bomet'),
  kakamega(37, 'Kakamega'),
  vihiga(38, 'Vihiga'),
  bungoma(39, 'Bungoma'),
  busia(40, 'Busia'),
  siaya(41, 'Siaya'),
  kisumu(42, 'Kisumu'),
  homaBay(43, 'Homa Bay'),
  migori(44, 'Migori'),
  kisii(45, 'Kisii'),
  nyamira(46, 'Nyamira'),
  nairobi(47, 'Nairobi');

  const KenyaCounty(this.number, this.label);
  final int number;
  final String label;
}

class KenyaCountyConverter extends TypeConverter<KenyaCounty, int> {
  const KenyaCountyConverter();
  @override
  KenyaCounty fromSql(int fromDb) =>
      KenyaCounty.values.firstWhere((e) => e.number == fromDb);
  @override
  int toSql(KenyaCounty value) => value.number;
}

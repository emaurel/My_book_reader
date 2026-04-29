// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Lorekeeper';

  @override
  String get navContinueReading => 'Lecture en cours';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navCitations => 'Citations';

  @override
  String get navDictionaries => 'Dictionnaires';

  @override
  String get navCharacters => 'Personnages';

  @override
  String get navLinks => 'Liens';

  @override
  String get navNotes => 'Notes';

  @override
  String get navStatistics => 'Statistiques';

  @override
  String get navDownloadBooks => 'Télécharger des livres';

  @override
  String get navBackup => 'Sauvegarde et restauration';

  @override
  String get navImportBundle => 'Importer un pack';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get actionOpen => 'Ouvrir';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionEditInfo => 'Modifier les infos';

  @override
  String get actionBookInfo => 'Infos du livre';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionRemove => 'Retirer';

  @override
  String get actionRemoveFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get actionShareBundle => 'Partager le pack du livre';

  @override
  String get actionShareSeriesBundle => 'Partager le pack de la série';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionAdd => 'Ajouter';

  @override
  String get actionRestore => 'Restaurer';

  @override
  String get actionExport => 'Exporter';

  @override
  String get actionImport => 'Importer';

  @override
  String get actionTimeline => 'Voir la chronologie';

  @override
  String get actionCopy => 'Copier';

  @override
  String get actionCopyText => 'Copier le texte';

  @override
  String get actionCopyPath => 'Copier le chemin';

  @override
  String get actionOK => 'OK';

  @override
  String get selectionCopy => 'Copier';

  @override
  String get selectionCitation => 'Citation';

  @override
  String get selectionDictionary => 'Dictionnaire';

  @override
  String get selectionCharacter => 'Personnage';

  @override
  String get selectionLink => 'Lien';

  @override
  String get selectionNote => 'Note';

  @override
  String get selectionTranslate => 'Traduire';

  @override
  String get selectionCopied => 'Copié';

  @override
  String get selectionSavedCitation => 'Citation enregistrée';

  @override
  String get selectionAddedToDictionary => 'Ajouté au dictionnaire';

  @override
  String get selectionSavedCharacter => 'Description de personnage enregistrée';

  @override
  String get selectionLinked => 'Lien créé';

  @override
  String get selectionLinkOpenBookFirst => 'Ouvrez un livre pour créer un lien';

  @override
  String get selectionNoteAdded => 'Note ajoutée';

  @override
  String get selectionTranslateFailed => 'Impossible d\'ouvrir le traducteur';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAppearanceFollowSystem => 'Suivre le système';

  @override
  String get settingsAppearanceLight => 'Clair';

  @override
  String get settingsAppearanceDark => 'Sombre';

  @override
  String get settingsLibrary => 'Bibliothèque';

  @override
  String get settingsShowDocuments => 'Afficher les documents';

  @override
  String get settingsShowDocumentsSubtitle =>
      'Inclure les PDF et les fichiers TXT à côté des livres';

  @override
  String get settingsReader => 'Lecteur';

  @override
  String get settingsSelectionMenu => 'Menu de sélection';

  @override
  String get settingsSelectionMenuSubtitle =>
      'Réorganiser les actions et choisir lesquelles vont dans « … »';

  @override
  String get settingsSelectionMenuHint =>
      'Glissez pour réorganiser. Activez « Dans le menu … » pour cacher une action derrière le bouton « … » au lieu de l\'afficher en ligne.';

  @override
  String get settingsSelectionMenuInOverflow => 'Dans le menu …';

  @override
  String get settingsSelectionMenuResetTooltip => 'Réinitialiser';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsSupportedFormats => 'Formats pris en charge';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSwedish => 'Suédois';

  @override
  String get libraryAddBooks => 'Ajouter des livres';

  @override
  String get libraryScanTooltip => 'Rechercher des livres sur l\'appareil';

  @override
  String get libraryRefreshTooltip => 'Actualiser couvertures et métadonnées';

  @override
  String get libraryRefreshing =>
      'Actualisation des couvertures et métadonnées…';

  @override
  String get libraryRefreshAllHave =>
      'Tous les livres ont déjà leurs métadonnées.';

  @override
  String libraryRefreshDone(int n) {
    return '$n livre(s) actualisé(s).';
  }

  @override
  String libraryRefreshFailed(String error) {
    return 'Échec de l\'actualisation : $error';
  }

  @override
  String get libraryScanning => 'Recherche de livres sur l\'appareil…';

  @override
  String get libraryScanNoneFound => 'Aucun nouveau livre trouvé.';

  @override
  String libraryScanAdded(int n) {
    return '$n livre(s) ajouté(s).';
  }

  @override
  String libraryScanFailed(String error) {
    return 'Échec de la recherche : $error';
  }

  @override
  String get libraryImportNone => 'Aucun nouveau livre ajouté.';

  @override
  String libraryImportAdded(int n) {
    return '$n livre(s) ajouté(s).';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String get libraryGroupOther => 'Autres';

  @override
  String get libraryEmptyTitle => 'Aucun livre pour le moment';

  @override
  String get libraryEmptyHint =>
      'Appuyez sur le bouton + pour importer des livres, ou utilisez l\'icône de recherche pour trouver des livres sur votre appareil.';

  @override
  String librarySeriesBooksCount(int n) {
    return '$n livre(s) dans la série';
  }

  @override
  String get libraryConfirmDeleteTitle => 'Retirer de la bibliothèque ?';

  @override
  String get libraryConfirmDeleteBody =>
      'Supprime ce livre et toutes ses annotations.';

  @override
  String get citationsEmptyTitle => 'Aucune citation pour le moment';

  @override
  String get citationsEmptyHint =>
      'Maintenez un passage du lecteur, puis appuyez sur « Citation » pour l\'enregistrer ici.';

  @override
  String get citationsCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get notesEmptyTitle => 'Aucune note pour le moment';

  @override
  String get notesEmptyHint =>
      'Maintenez un passage dans le lecteur, appuyez sur « … » puis sur « Note » pour y attacher une pensée.';

  @override
  String get notesAdd => 'Ajouter une note';

  @override
  String get notesEdit => 'Modifier la note';

  @override
  String get notesPromptHint => 'Votre note';

  @override
  String get charactersEmptyTitle => 'Aucun personnage pour le moment';

  @override
  String get charactersEmptyHint =>
      'Dans le lecteur, maintenez un passage qui décrit un personnage et appuyez sur « Personnage ».';

  @override
  String get charactersUnaffiliated => 'Sans affiliation';

  @override
  String get charactersDeleteTooltip => 'Supprimer le personnage';

  @override
  String get charactersTimelineTooltip => 'Voir la chronologie';

  @override
  String charactersDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get charactersDeleteBody =>
      'Supprime le personnage et toutes ses descriptions enregistrées.';

  @override
  String get charactersAddToCharacter => 'Associer à un personnage';

  @override
  String get charactersEnterName => 'Entrez le nom du personnage.';

  @override
  String charactersCreateError(String error) {
    return 'Impossible de créer le personnage : $error';
  }

  @override
  String charactersAliasesLabel(String names) {
    return 'alias $names';
  }

  @override
  String get charactersNoDescriptions => 'Aucune description enregistrée.';

  @override
  String charactersRevealSpoilers(int n) {
    return 'Révéler $n spoiler(s) à venir';
  }

  @override
  String get charactersScopeToSeries => 'Limiter à la série';

  @override
  String charactersTimelineTitle(String name) {
    return '$name — chronologie';
  }

  @override
  String get charactersTimelineBookLabel => 'Livre';

  @override
  String get charactersTimelineNoEpub =>
      'Aucun livre EPUB trouvé dans la série de ce personnage.';

  @override
  String charactersTimelineNotMentioned(String name) {
    return '$name n\'est pas mentionné dans ce livre.';
  }

  @override
  String get charactersTimelineEpubOnly =>
      'Chronologie disponible uniquement pour EPUB.';

  @override
  String charactersTimelineMentions(int n) {
    return '$n mention(s)';
  }

  @override
  String get dictionariesEmptyTitle => 'Aucun dictionnaire pour le moment';

  @override
  String get dictionariesEmptyHint =>
      'Maintenez un mot dans le lecteur et appuyez sur « Dictionnaire » pour enregistrer sa définition.';

  @override
  String get dictionariesAddDictionary => 'Créer un dictionnaire';

  @override
  String get dictionariesDictionaryName => 'Nom du dictionnaire';

  @override
  String get dictionariesDescription => 'Description';

  @override
  String get dictionariesNoEntries => 'Aucune entrée pour le moment.';

  @override
  String get linksEmptyTitle => 'Aucun lien pour le moment';

  @override
  String get linksEmptyHint =>
      'Maintenez un passage dans le lecteur et appuyez sur « Lien » pour pointer vers un autre livre de votre bibliothèque.';

  @override
  String get linksTabList => 'Liste';

  @override
  String get linksTabGraph => 'Graphe';

  @override
  String get linksOpenSource => 'Ouvrir le livre source';

  @override
  String get linksOpenTarget => 'Ouvrir le livre cible';

  @override
  String get linksGraphEmpty =>
      'Aucun lien — créez-en depuis le menu de sélection du lecteur.';

  @override
  String get linksPickerTitle => 'Lier à un livre';

  @override
  String get linksPickerSearchHint => 'Rechercher par titre ou auteur';

  @override
  String get linksPickerNoOthers => 'Aucun autre livre dans votre bibliothèque';

  @override
  String get linksPickerNoMatches => 'Aucune correspondance';

  @override
  String get linksSheetFromBook => 'Liens depuis ce livre';

  @override
  String get linksSheetToBook => 'Liens vers ce livre';

  @override
  String get linksSheetNoLinks => 'Aucun lien';

  @override
  String get statsTabDay => 'Jour';

  @override
  String get statsTabWeek => 'Semaine';

  @override
  String get statsTabMonth => 'Mois';

  @override
  String get statsTabAllTime => 'Tout';

  @override
  String get statsCardPages => 'Pages';

  @override
  String get statsCardWords => 'Mots';

  @override
  String get statsCardPagesPerHour => 'Pages / h';

  @override
  String get statsCardWordsPerHour => 'Mots / h';

  @override
  String get statsCardBooks => 'Livres';

  @override
  String get statsCardBooksFinished => 'terminés';

  @override
  String get statsCardActiveReading => 'lecture active';

  @override
  String get statsCaptionLast24h => '24 dernières h';

  @override
  String get statsCaptionLast7d => '7 derniers jours';

  @override
  String get statsCaptionLast30d => '30 derniers jours';

  @override
  String get statsCaptionAllTime => 'depuis le début';

  @override
  String statsEmptyForRange(String caption) {
    return 'Aucune lecture enregistrée $caption.';
  }

  @override
  String get statsFinishedSheetTitle => 'Livres terminés';

  @override
  String get statsMarkAsNotFinished => 'Marquer comme non terminé';

  @override
  String get backupExportButton => 'Exporter la sauvegarde';

  @override
  String get backupRestoreButton => 'Restaurer une sauvegarde';

  @override
  String get backupIntro =>
      'L\'export regroupe les fichiers de votre bibliothèque, les couvertures, la base de données (livres, citations, personnages, dictionnaires, progression) et les paramètres de lecture dans un seul .zip que vous pouvez partager ou conserver hors de l\'appareil.';

  @override
  String get backupRestoreFooter =>
      'La restauration écrase toutes les données actuelles. L\'app doit être fermée et rouverte pour que la modification soit effective.';

  @override
  String get backupReplaceTitle => 'Remplacer toutes les données ?';

  @override
  String get backupReplaceBody =>
      'La restauration écrasera définitivement votre bibliothèque, citations, personnages, dictionnaire et paramètres de lecture par le contenu de la sauvegarde. Action irréversible.';

  @override
  String get backupRestoreCompleteTitle => 'Restauration terminée';

  @override
  String backupRestoreCompleteBody(int n, String takenAt) {
    return '$n fichiers restaurés$takenAt\n\nFermez et rouvrez l\'app pour charger les données restaurées.';
  }

  @override
  String backupTakenAtSuffix(String at) {
    return '\nSauvegarde du $at';
  }

  @override
  String backupWrittenTo(String path) {
    return 'Sauvegarde écrite dans $path';
  }

  @override
  String backupExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String backupRestoreFailed(String error) {
    return 'Échec de la restauration : $error';
  }

  @override
  String get backupPermissionWarning =>
      'Permission de stockage refusée — la sauvegarde sera enregistrée dans le stockage privé de l\'app et ne sera accessible que via Partager.';

  @override
  String get bundleShareTitle => 'Partager le pack du livre';

  @override
  String bundleShareDescription(String label, String suffix) {
    return 'Regroupe « $label »$suffix avec ses citations, notes, personnages, entrées de dictionnaire et liens dans un seul .zip que vous pouvez partager.';
  }

  @override
  String bundleSeriesSuffix(int count) {
    return ' ($count livres)';
  }

  @override
  String get bundleIncludeLinkedTitle => 'Inclure les livres liés';

  @override
  String get bundleIncludeLinkedSubtitle =>
      'Inclure récursivement tous les livres atteignables via des liens';

  @override
  String get bundleIncludeProgressTitle => 'Inclure la progression de lecture';

  @override
  String get bundleIncludeProgressSubtitle =>
      'Désactivé par défaut — pratique pour partager avec des amis';

  @override
  String bundleSubject(String title) {
    return 'Pack de livre : $title';
  }

  @override
  String bundleSavedTo(String path) {
    return 'Pack enregistré dans $path';
  }

  @override
  String bundleExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get importBundleTitle => 'Importer un pack';

  @override
  String get importBundleIntro =>
      'Choisissez un .zip exporté depuis une autre installation de Lorekeeper. Les livres avec le même titre, auteur et taille sont fusionnés sur place ; sinon une copie est ajoutée à votre bibliothèque.';

  @override
  String get importBundlePick => 'Choisir un fichier';

  @override
  String get importBundleProgressIncluded =>
      'Inclut la progression de lecture — vos positions actuelles seront remplacées pour les livres correspondants.';

  @override
  String get importBundleBooksHeader => 'Livres dans le pack :';

  @override
  String importBundleSummary(int added, int merged, int citations, int notes,
      int chars, int dicts, int links) {
    return '$added livre(s) importé(s) ($merged fusionné(s)). $citations citations, $notes notes, $chars personnages, $dicts entrées de dictionnaire, $links liens.';
  }

  @override
  String get downloadsTitle => 'Télécharger des livres';

  @override
  String get downloadsKeyMissing =>
      'Clé RapidAPI absente. Modifiez lib/features/downloads/services/anna_archive_api.dart et collez votre clé dans _rapidApiKey, ou lancez avec --dart-define=RAPIDAPI_KEY=…';

  @override
  String get readerWorking => 'En cours…';
}

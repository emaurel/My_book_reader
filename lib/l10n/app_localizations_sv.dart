// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'Lorekeeper';

  @override
  String get navContinueReading => 'Fortsätt läsa';

  @override
  String get navLibrary => 'Bibliotek';

  @override
  String get navCitations => 'Citat';

  @override
  String get navDictionaries => 'Ordböcker';

  @override
  String get navCharacters => 'Karaktärer';

  @override
  String get navLinks => 'Länkar';

  @override
  String get navNotes => 'Anteckningar';

  @override
  String get navStatistics => 'Statistik';

  @override
  String get navDownloadBooks => 'Ladda ner böcker';

  @override
  String get navBackup => 'Säkerhetskopiering';

  @override
  String get navImportBundle => 'Importera paket';

  @override
  String get navSettings => 'Inställningar';

  @override
  String get actionOpen => 'Öppna';

  @override
  String get actionEdit => 'Redigera';

  @override
  String get actionEditInfo => 'Redigera info';

  @override
  String get actionBookInfo => 'Bokinfo';

  @override
  String get actionDelete => 'Ta bort';

  @override
  String get actionRemove => 'Ta bort';

  @override
  String get actionRemoveFromLibrary => 'Ta bort från biblioteket';

  @override
  String get actionShareBundle => 'Dela bokpaket';

  @override
  String get actionShareSeriesBundle => 'Dela seriepaket';

  @override
  String get actionCancel => 'Avbryt';

  @override
  String get actionSave => 'Spara';

  @override
  String get actionAdd => 'Lägg till';

  @override
  String get actionRestore => 'Återställ';

  @override
  String get actionExport => 'Exportera';

  @override
  String get actionImport => 'Importera';

  @override
  String get actionTimeline => 'Visa tidslinje';

  @override
  String get actionCopy => 'Kopiera';

  @override
  String get actionCopyText => 'Kopiera text';

  @override
  String get actionCopyPath => 'Kopiera sökväg';

  @override
  String get actionOK => 'OK';

  @override
  String get selectionCopy => 'Kopiera';

  @override
  String get selectionCitation => 'Citat';

  @override
  String get selectionDictionary => 'Ordbok';

  @override
  String get selectionCharacter => 'Karaktär';

  @override
  String get selectionLink => 'Länk';

  @override
  String get selectionNote => 'Anteckning';

  @override
  String get selectionTranslate => 'Översätt';

  @override
  String get selectionCopied => 'Kopierat';

  @override
  String get selectionSavedCitation => 'Citat sparat';

  @override
  String get selectionAddedToDictionary => 'Tillagd i ordboken';

  @override
  String get selectionSavedCharacter => 'Karaktärsbeskrivning sparad';

  @override
  String get selectionLinked => 'Länk skapad';

  @override
  String get selectionLinkOpenBookFirst => 'Öppna en bok för att skapa en länk';

  @override
  String get selectionNoteAdded => 'Anteckning tillagd';

  @override
  String get selectionTranslateFailed => 'Kunde inte öppna översättaren';

  @override
  String get settingsAppearance => 'Utseende';

  @override
  String get settingsAppearanceFollowSystem => 'Följ systemet';

  @override
  String get settingsAppearanceLight => 'Ljust';

  @override
  String get settingsAppearanceDark => 'Mörkt';

  @override
  String get settingsLibrary => 'Bibliotek';

  @override
  String get settingsShowDocuments => 'Visa dokument';

  @override
  String get settingsShowDocumentsSubtitle =>
      'Inkludera PDF- och TXT-filer tillsammans med böcker';

  @override
  String get settingsReader => 'Läsare';

  @override
  String get settingsSelectionMenu => 'Markeringsmeny';

  @override
  String get settingsSelectionMenuSubtitle =>
      'Ändra ordning på åtgärder och välj vilka som hamnar i ”…”';

  @override
  String get settingsSelectionMenuHint =>
      'Dra för att ändra ordning. Aktivera ”I ”…”-menyn” för att gömma en åtgärd bakom ”…”-knappen istället för att visa den direkt.';

  @override
  String get settingsSelectionMenuInOverflow => 'I ”…”-menyn';

  @override
  String get settingsSelectionMenuResetTooltip => 'Återställ standard';

  @override
  String get settingsLanguage => 'Språk';

  @override
  String get settingsLanguageSystem => 'Systemspråk';

  @override
  String get settingsAbout => 'Om';

  @override
  String get settingsSupportedFormats => 'Stödda format';

  @override
  String get languageEnglish => 'Engelska';

  @override
  String get languageFrench => 'Franska';

  @override
  String get languageSwedish => 'Svenska';

  @override
  String get libraryAddBooks => 'Lägg till böcker';

  @override
  String get libraryScanTooltip => 'Sök efter böcker på enheten';

  @override
  String get libraryRefreshTooltip => 'Uppdatera omslag och metadata';

  @override
  String get libraryRefreshing => 'Uppdaterar omslag och metadata…';

  @override
  String get libraryRefreshAllHave => 'Alla böcker har redan metadata.';

  @override
  String libraryRefreshDone(int n) {
    return '$n bok/böcker uppdaterade.';
  }

  @override
  String libraryRefreshFailed(String error) {
    return 'Uppdateringen misslyckades: $error';
  }

  @override
  String get libraryScanning => 'Söker efter böcker på enheten…';

  @override
  String get libraryScanNoneFound => 'Inga nya böcker hittades.';

  @override
  String libraryScanAdded(int n) {
    return '$n bok/böcker hittades och lades till.';
  }

  @override
  String libraryScanFailed(String error) {
    return 'Sökningen misslyckades: $error';
  }

  @override
  String get libraryImportNone => 'Inga nya böcker tillagda.';

  @override
  String libraryImportAdded(int n) {
    return '$n bok/böcker tillagda.';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Importen misslyckades: $error';
  }

  @override
  String get libraryGroupOther => 'Övrigt';

  @override
  String get libraryEmptyTitle => 'Inga böcker än';

  @override
  String get libraryEmptyHint =>
      'Tryck på +-knappen för att importera böcker, eller tryck på sökikonen för att hitta böcker på enheten.';

  @override
  String librarySeriesBooksCount(int n) {
    return '$n bok/böcker i serien';
  }

  @override
  String get libraryConfirmDeleteTitle => 'Ta bort från biblioteket?';

  @override
  String get libraryConfirmDeleteBody =>
      'Tar bort den här boken och alla dess anteckningar.';

  @override
  String get citationsEmptyTitle => 'Inga citat än';

  @override
  String get citationsEmptyHint =>
      'Håll inne på ett stycke i läsaren och tryck på ”Citat” för att spara det här.';

  @override
  String get citationsCopiedToClipboard => 'Kopierat till urklipp';

  @override
  String get notesEmptyTitle => 'Inga anteckningar än';

  @override
  String get notesEmptyHint =>
      'Håll inne på ett stycke i läsaren, tryck på ”…” och sedan på ”Anteckning” för att fästa en tanke.';

  @override
  String get notesAdd => 'Lägg till anteckning';

  @override
  String get notesEdit => 'Redigera anteckning';

  @override
  String get notesPromptHint => 'Din anteckning';

  @override
  String get charactersEmptyTitle => 'Inga karaktärer än';

  @override
  String get charactersEmptyHint =>
      'I läsaren, håll inne på ett stycke som beskriver en karaktär och tryck på ”Karaktär”.';

  @override
  String get charactersUnaffiliated => 'Utan tillhörighet';

  @override
  String get charactersDeleteTooltip => 'Ta bort karaktär';

  @override
  String get charactersTimelineTooltip => 'Visa tidslinje';

  @override
  String charactersDeleteTitle(String name) {
    return 'Ta bort ”$name”?';
  }

  @override
  String get charactersDeleteBody =>
      'Tar bort karaktären och alla sparade beskrivningar.';

  @override
  String get charactersAddToCharacter => 'Lägg till på karaktär';

  @override
  String get charactersEnterName => 'Ange karaktärens namn.';

  @override
  String charactersCreateError(String error) {
    return 'Kunde inte skapa karaktären: $error';
  }

  @override
  String charactersAliasesLabel(String names) {
    return 'alias $names';
  }

  @override
  String get charactersNoDescriptions => 'Inga beskrivningar sparade än.';

  @override
  String charactersRevealSpoilers(int n) {
    return 'Visa $n spoiler/spoilers längre fram';
  }

  @override
  String get charactersScopeToSeries => 'Begränsa till serie';

  @override
  String charactersTimelineTitle(String name) {
    return '$name — tidslinje';
  }

  @override
  String get charactersTimelineBookLabel => 'Bok';

  @override
  String get charactersTimelineNoEpub =>
      'Inga EPUB-böcker hittades i karaktärens serie.';

  @override
  String charactersTimelineNotMentioned(String name) {
    return '$name nämns inte i den här boken.';
  }

  @override
  String get charactersTimelineEpubOnly =>
      'Tidslinjen är bara tillgänglig för EPUB.';

  @override
  String charactersTimelineMentions(int n) {
    return '$n omnämnande(n)';
  }

  @override
  String get dictionariesEmptyTitle => 'Inga ordböcker än';

  @override
  String get dictionariesEmptyHint =>
      'Håll inne på ett ord i läsaren och tryck på ”Ordbok” för att spara dess definition.';

  @override
  String get dictionariesAddDictionary => 'Skapa ordbok';

  @override
  String get dictionariesDictionaryName => 'Ordbokens namn';

  @override
  String get dictionariesDescription => 'Beskrivning';

  @override
  String get dictionariesNoEntries => 'Inga poster än.';

  @override
  String get linksEmptyTitle => 'Inga länkar än';

  @override
  String get linksEmptyHint =>
      'Håll inne på ett stycke i läsaren och tryck på ”Länk” för att peka på en annan bok i biblioteket.';

  @override
  String get linksTabList => 'Lista';

  @override
  String get linksTabGraph => 'Graf';

  @override
  String get linksOpenSource => 'Öppna källboken';

  @override
  String get linksOpenTarget => 'Öppna målboken';

  @override
  String get linksGraphEmpty =>
      'Inga länkar — skapa några från läsarens markeringsmeny först.';

  @override
  String get linksPickerTitle => 'Länka till bok';

  @override
  String get linksPickerSearchHint => 'Sök efter titel eller författare';

  @override
  String get linksPickerNoOthers => 'Inga andra böcker i biblioteket';

  @override
  String get linksPickerNoMatches => 'Inga träffar';

  @override
  String get linksSheetFromBook => 'Länkar från denna bok';

  @override
  String get linksSheetToBook => 'Länkar till denna bok';

  @override
  String get linksSheetNoLinks => 'Inga länkar';

  @override
  String get statsTabDay => 'Dag';

  @override
  String get statsTabWeek => 'Vecka';

  @override
  String get statsTabMonth => 'Månad';

  @override
  String get statsTabAllTime => 'Allt';

  @override
  String get statsCardPages => 'Sidor';

  @override
  String get statsCardWords => 'Ord';

  @override
  String get statsCardPagesPerHour => 'Sidor / h';

  @override
  String get statsCardWordsPerHour => 'Ord / h';

  @override
  String get statsCardBooks => 'Böcker';

  @override
  String get statsCardBooksFinished => 'färdiglästa';

  @override
  String get statsCardActiveReading => 'aktiv läsning';

  @override
  String get statsCaptionLast24h => 'senaste 24 h';

  @override
  String get statsCaptionLast7d => 'senaste 7 dagarna';

  @override
  String get statsCaptionLast30d => 'senaste 30 dagarna';

  @override
  String get statsCaptionAllTime => 'från början';

  @override
  String statsEmptyForRange(String caption) {
    return 'Ingen läsning registrerad $caption.';
  }

  @override
  String get statsFinishedSheetTitle => 'Färdiglästa böcker';

  @override
  String get statsMarkAsNotFinished => 'Markera som ej färdigläst';

  @override
  String get backupExportButton => 'Exportera säkerhetskopia';

  @override
  String get backupRestoreButton => 'Återställ från säkerhetskopia';

  @override
  String get backupIntro =>
      'Exporten paketerar ditt biblioteks filer, omslag, databas (böcker, citat, karaktärer, ordbok, framsteg) och läsarinställningar i en enda .zip som du kan dela eller spara utanför enheten.';

  @override
  String get backupRestoreFooter =>
      'Återställning skriver över alla nuvarande data. Appen måste stängas och öppnas igen efteråt för att ändringen ska träda i kraft.';

  @override
  String get backupReplaceTitle => 'Ersätt all data?';

  @override
  String get backupReplaceBody =>
      'Återställning skriver över ditt nuvarande bibliotek, citat, karaktärer, ordbok och läsarinställningar med innehållet i säkerhetskopian. Detta går inte att ångra.';

  @override
  String get backupRestoreCompleteTitle => 'Återställning klar';

  @override
  String backupRestoreCompleteBody(int n, String takenAt) {
    return '$n filer återställda$takenAt\n\nStäng och öppna appen igen för att läsa in den återställda datan.';
  }

  @override
  String backupTakenAtSuffix(String at) {
    return '\nSäkerhetskopia tagen $at';
  }

  @override
  String backupWrittenTo(String path) {
    return 'Säkerhetskopia skriven till $path';
  }

  @override
  String backupExportFailed(String error) {
    return 'Exporten misslyckades: $error';
  }

  @override
  String backupRestoreFailed(String error) {
    return 'Återställningen misslyckades: $error';
  }

  @override
  String get backupPermissionWarning =>
      'Lagringsbehörighet nekad — säkerhetskopian sparas i appens privata lagring och nås endast via Dela.';

  @override
  String get bundleShareTitle => 'Dela bokpaket';

  @override
  String bundleShareDescription(String label, String suffix) {
    return 'Paketerar ”$label”$suffix tillsammans med citat, anteckningar, karaktärer, ordboksposter och länkar i en enda .zip som du kan dela.';
  }

  @override
  String bundleSeriesSuffix(int count) {
    return ' ($count böcker)';
  }

  @override
  String get bundleIncludeLinkedTitle => 'Inkludera länkade böcker';

  @override
  String get bundleIncludeLinkedSubtitle =>
      'Inkludera rekursivt alla böcker som nås via länkar';

  @override
  String get bundleIncludeProgressTitle => 'Inkludera läsframsteg';

  @override
  String get bundleIncludeProgressSubtitle =>
      'Av som standard — användbart vid delning med vänner';

  @override
  String bundleSubject(String title) {
    return 'Bokpaket: $title';
  }

  @override
  String bundleSavedTo(String path) {
    return 'Paket sparat till $path';
  }

  @override
  String bundleExportFailed(String error) {
    return 'Exporten misslyckades: $error';
  }

  @override
  String get importBundleTitle => 'Importera paket';

  @override
  String get importBundleIntro =>
      'Välj en .zip exporterad från en annan Lorekeeper-installation. Befintliga böcker med samma titel, författare och storlek slås samman på plats; annars läggs en kopia till i ditt bibliotek.';

  @override
  String get importBundlePick => 'Välj paketfil';

  @override
  String get importBundleProgressIncluded =>
      'Inkluderar läsframsteg — dina senaste positioner ersätts för matchande böcker.';

  @override
  String get importBundleBooksHeader => 'Böcker i paketet:';

  @override
  String importBundleSummary(int added, int merged, int citations, int notes,
      int chars, int dicts, int links) {
    return '$added ny(a) bok/böcker importerade ($merged matchade befintliga). $citations citat, $notes anteckningar, $chars karaktärer, $dicts ordboksposter, $links länkar.';
  }

  @override
  String get downloadsTitle => 'Ladda ner böcker';

  @override
  String get downloadsKeyMissing =>
      'RapidAPI-nyckel saknas. Redigera lib/features/downloads/services/anna_archive_api.dart och klistra in din nyckel i _rapidApiKey, eller kör med --dart-define=RAPIDAPI_KEY=…';

  @override
  String get readerWorking => 'Arbetar…';
}

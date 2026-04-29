// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lorekeeper';

  @override
  String get navContinueReading => 'Continue reading';

  @override
  String get navLibrary => 'Library';

  @override
  String get navCitations => 'Citations';

  @override
  String get navDictionaries => 'Dictionaries';

  @override
  String get navCharacters => 'Characters';

  @override
  String get navLinks => 'Links';

  @override
  String get navNotes => 'Notes';

  @override
  String get navStatistics => 'Statistics';

  @override
  String get navDownloadBooks => 'Download books';

  @override
  String get navBackup => 'Backup & restore';

  @override
  String get navImportBundle => 'Import bundle';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionEditInfo => 'Edit info';

  @override
  String get actionBookInfo => 'Book info';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionRemoveFromLibrary => 'Remove from library';

  @override
  String get actionShareBundle => 'Share book bundle';

  @override
  String get actionShareSeriesBundle => 'Share series bundle';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionExport => 'Export';

  @override
  String get actionImport => 'Import';

  @override
  String get actionTimeline => 'View timeline';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopyText => 'Copy text';

  @override
  String get actionCopyPath => 'Copy path';

  @override
  String get actionOK => 'OK';

  @override
  String get selectionCopy => 'Copy';

  @override
  String get selectionCitation => 'Citation';

  @override
  String get selectionDictionary => 'Dictionary';

  @override
  String get selectionCharacter => 'Character';

  @override
  String get selectionLink => 'Link';

  @override
  String get selectionNote => 'Note';

  @override
  String get selectionTranslate => 'Translate';

  @override
  String get selectionCopied => 'Copied';

  @override
  String get selectionSavedCitation => 'Saved citation';

  @override
  String get selectionAddedToDictionary => 'Added to dictionary';

  @override
  String get selectionSavedCharacter => 'Saved character description';

  @override
  String get selectionLinked => 'Linked';

  @override
  String get selectionLinkOpenBookFirst => 'Open a book to link';

  @override
  String get selectionNoteAdded => 'Note added';

  @override
  String get selectionTranslateFailed => 'Could not open translator';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceFollowSystem => 'Follow system';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get settingsShowDocuments => 'Show documents';

  @override
  String get settingsShowDocumentsSubtitle =>
      'Include PDFs and TXT files alongside books';

  @override
  String get settingsReader => 'Reader';

  @override
  String get settingsSelectionMenu => 'Selection menu';

  @override
  String get settingsSelectionMenuSubtitle =>
      'Reorder actions and choose which appear in \"…\"';

  @override
  String get settingsSelectionMenuHint =>
      'Drag to reorder. Toggle \"In overflow\" to hide an action behind the \"…\" menu instead of showing it inline.';

  @override
  String get settingsSelectionMenuInOverflow => 'In overflow';

  @override
  String get settingsSelectionMenuResetTooltip => 'Reset to defaults';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSupportedFormats => 'Supported formats';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSwedish => 'Swedish';

  @override
  String get libraryAddBooks => 'Add books';

  @override
  String get libraryScanTooltip => 'Scan device for books';

  @override
  String get libraryRefreshTooltip => 'Refresh covers & metadata';

  @override
  String get libraryRefreshing => 'Refreshing covers & metadata…';

  @override
  String get libraryRefreshAllHave => 'All books already have metadata.';

  @override
  String libraryRefreshDone(int n) {
    return 'Refreshed $n book(s).';
  }

  @override
  String libraryRefreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get libraryScanning => 'Scanning device for books…';

  @override
  String get libraryScanNoneFound => 'No new books found.';

  @override
  String libraryScanAdded(int n) {
    return 'Found and added $n book(s).';
  }

  @override
  String libraryScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get libraryImportNone => 'No new books added.';

  @override
  String libraryImportAdded(int n) {
    return 'Added $n book(s).';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get libraryGroupOther => 'Other';

  @override
  String get libraryEmptyTitle => 'No books yet';

  @override
  String get libraryEmptyHint =>
      'Tap the + button to import books, or use the scan icon to find books on your device.';

  @override
  String librarySeriesBooksCount(int n) {
    return '$n book(s) in series';
  }

  @override
  String get libraryConfirmDeleteTitle => 'Remove from library?';

  @override
  String get libraryConfirmDeleteBody =>
      'Removes this book and all its annotations.';

  @override
  String get citationsEmptyTitle => 'No citations yet';

  @override
  String get citationsEmptyHint =>
      'Long-press a passage in the reader and tap \"Citation\" to save it here.';

  @override
  String get citationsCopiedToClipboard => 'Copied to clipboard';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String get notesEmptyHint =>
      'Long-press a passage in the reader, tap \"…\" then \"Note\" to attach a thought.';

  @override
  String get notesAdd => 'Add note';

  @override
  String get notesEdit => 'Edit note';

  @override
  String get notesPromptHint => 'Your note';

  @override
  String get charactersEmptyTitle => 'No characters yet';

  @override
  String get charactersEmptyHint =>
      'In the reader, long-press a passage that describes a character and tap \"Character\".';

  @override
  String get charactersUnaffiliated => 'Unaffiliated';

  @override
  String get charactersDeleteTooltip => 'Delete character';

  @override
  String get charactersTimelineTooltip => 'View timeline';

  @override
  String charactersDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get charactersDeleteBody =>
      'Removes the character and every saved description.';

  @override
  String get charactersAddToCharacter => 'Add to character';

  @override
  String get charactersEnterName => 'Enter the character\'s name.';

  @override
  String charactersCreateError(String error) {
    return 'Could not create character: $error';
  }

  @override
  String charactersAliasesLabel(String names) {
    return 'a.k.a. $names';
  }

  @override
  String get charactersNoDescriptions => 'No descriptions saved yet.';

  @override
  String charactersRevealSpoilers(int n) {
    return 'Reveal $n spoiler(s) ahead of you';
  }

  @override
  String get charactersScopeToSeries => 'Scope to series';

  @override
  String charactersTimelineTitle(String name) {
    return '$name — timeline';
  }

  @override
  String get charactersTimelineBookLabel => 'Book';

  @override
  String get charactersTimelineNoEpub =>
      'No EPUB books found in this character\'s series.';

  @override
  String charactersTimelineNotMentioned(String name) {
    return '$name is not mentioned in this book.';
  }

  @override
  String get charactersTimelineEpubOnly => 'Timeline available for EPUB only.';

  @override
  String charactersTimelineMentions(int n) {
    return '$n mention(s)';
  }

  @override
  String get dictionariesEmptyTitle => 'No dictionaries yet';

  @override
  String get dictionariesEmptyHint =>
      'Long-press a word in the reader and tap \"Dictionary\" to save its definition.';

  @override
  String get dictionariesAddDictionary => 'Create dictionary';

  @override
  String get dictionariesDictionaryName => 'Dictionary name';

  @override
  String get dictionariesDescription => 'Description';

  @override
  String get dictionariesNoEntries => 'No entries yet.';

  @override
  String get linksEmptyTitle => 'No links yet';

  @override
  String get linksEmptyHint =>
      'Long-press a passage in the reader and tap \"Link\" to point at another book in your library.';

  @override
  String get linksTabList => 'List';

  @override
  String get linksTabGraph => 'Graph';

  @override
  String get linksOpenSource => 'Open source book';

  @override
  String get linksOpenTarget => 'Open target book';

  @override
  String get linksGraphEmpty =>
      'No links yet — add some from the reader\'s selection menu first.';

  @override
  String get linksPickerTitle => 'Link to book';

  @override
  String get linksPickerSearchHint => 'Search by title or author';

  @override
  String get linksPickerNoOthers => 'No other books in your library';

  @override
  String get linksPickerNoMatches => 'No matches';

  @override
  String get linksSheetFromBook => 'Links from this book';

  @override
  String get linksSheetToBook => 'Links to this book';

  @override
  String get linksSheetNoLinks => 'No links';

  @override
  String get statsTabDay => 'Day';

  @override
  String get statsTabWeek => 'Week';

  @override
  String get statsTabMonth => 'Month';

  @override
  String get statsTabAllTime => 'All time';

  @override
  String get statsCardPages => 'Pages';

  @override
  String get statsCardWords => 'Words';

  @override
  String get statsCardPagesPerHour => 'Pages / hour';

  @override
  String get statsCardWordsPerHour => 'Words / hour';

  @override
  String get statsCardBooks => 'Books';

  @override
  String get statsCardBooksFinished => 'finished';

  @override
  String get statsCardActiveReading => 'active reading';

  @override
  String get statsCaptionLast24h => 'last 24h';

  @override
  String get statsCaptionLast7d => 'last 7 days';

  @override
  String get statsCaptionLast30d => 'last 30 days';

  @override
  String get statsCaptionAllTime => 'all time';

  @override
  String statsEmptyForRange(String caption) {
    return 'No reading recorded $caption yet.';
  }

  @override
  String get statsFinishedSheetTitle => 'Finished books';

  @override
  String get statsMarkAsNotFinished => 'Mark as not finished';

  @override
  String get backupExportButton => 'Export backup';

  @override
  String get backupRestoreButton => 'Restore from backup';

  @override
  String get backupIntro =>
      'Export bundles your library files, covers, database (books, citations, characters, dictionary, progress) and reader settings into a single .zip you can share or save off-device.';

  @override
  String get backupRestoreFooter =>
      'Restoring overwrites all current data. The app must be closed and reopened afterwards for the change to take effect.';

  @override
  String get backupReplaceTitle => 'Replace all data?';

  @override
  String get backupReplaceBody =>
      'Restoring will permanently overwrite your current library, citations, characters, dictionary, and reader settings with the contents of the backup. This cannot be undone.';

  @override
  String get backupRestoreCompleteTitle => 'Restore complete';

  @override
  String backupRestoreCompleteBody(int n, String takenAt) {
    return 'Restored $n files$takenAt\n\nClose and reopen the app to load the restored data.';
  }

  @override
  String backupTakenAtSuffix(String at) {
    return '\nBackup taken $at';
  }

  @override
  String backupWrittenTo(String path) {
    return 'Backup written to $path';
  }

  @override
  String backupExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String backupRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get backupPermissionWarning =>
      'Storage permission denied — backup will be saved in app-private storage and will only be accessible via Share.';

  @override
  String get bundleShareTitle => 'Share book bundle';

  @override
  String bundleShareDescription(String label, String suffix) {
    return 'Bundles \"$label\"$suffix together with citations, notes, characters, dictionary entries, and links into a single .zip you can share.';
  }

  @override
  String bundleSeriesSuffix(int count) {
    return ' ($count books)';
  }

  @override
  String get bundleIncludeLinkedTitle => 'Include linked books';

  @override
  String get bundleIncludeLinkedSubtitle =>
      'Recursively pull in every book reachable through links';

  @override
  String get bundleIncludeProgressTitle => 'Include reading progress';

  @override
  String get bundleIncludeProgressSubtitle =>
      'Off by default — useful when sharing with friends';

  @override
  String bundleSubject(String title) {
    return 'Book bundle: $title';
  }

  @override
  String bundleSavedTo(String path) {
    return 'Bundle saved to $path';
  }

  @override
  String bundleExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importBundleTitle => 'Import bundle';

  @override
  String get importBundleIntro =>
      'Pick a .zip bundle exported from another Lorekeeper install. Existing books with the same title, author, and size are merged in place; otherwise a copy is added to your library.';

  @override
  String get importBundlePick => 'Pick bundle file';

  @override
  String get importBundleProgressIncluded =>
      'Includes reading progress — your last-read positions will be replaced for matching books.';

  @override
  String get importBundleBooksHeader => 'Books in bundle:';

  @override
  String importBundleSummary(int added, int merged, int citations, int notes,
      int chars, int dicts, int links) {
    return 'Imported $added new book(s) ($merged matched existing). $citations citations, $notes notes, $chars characters, $dicts dict entries, $links links.';
  }

  @override
  String get downloadsTitle => 'Download books';

  @override
  String get downloadsKeyMissing =>
      'RapidAPI key not set. Edit lib/features/downloads/services/anna_archive_api.dart and paste your key into _rapidApiKey, or run with --dart-define=RAPIDAPI_KEY=…';

  @override
  String get readerWorking => 'Working…';
}

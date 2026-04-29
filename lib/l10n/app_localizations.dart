import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('sv')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Lorekeeper'**
  String get appTitle;

  /// No description provided for @navContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get navContinueReading;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navCitations.
  ///
  /// In en, this message translates to:
  /// **'Citations'**
  String get navCitations;

  /// No description provided for @navDictionaries.
  ///
  /// In en, this message translates to:
  /// **'Dictionaries'**
  String get navDictionaries;

  /// No description provided for @navCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get navCharacters;

  /// No description provided for @navLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get navLinks;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navStatistics;

  /// No description provided for @navDownloadBooks.
  ///
  /// In en, this message translates to:
  /// **'Download books'**
  String get navDownloadBooks;

  /// No description provided for @navBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get navBackup;

  /// No description provided for @navImportBundle.
  ///
  /// In en, this message translates to:
  /// **'Import bundle'**
  String get navImportBundle;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit info'**
  String get actionEditInfo;

  /// No description provided for @actionBookInfo.
  ///
  /// In en, this message translates to:
  /// **'Book info'**
  String get actionBookInfo;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionRemoveFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get actionRemoveFromLibrary;

  /// No description provided for @actionShareBundle.
  ///
  /// In en, this message translates to:
  /// **'Share book bundle'**
  String get actionShareBundle;

  /// No description provided for @actionShareSeriesBundle.
  ///
  /// In en, this message translates to:
  /// **'Share series bundle'**
  String get actionShareSeriesBundle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @actionTimeline.
  ///
  /// In en, this message translates to:
  /// **'View timeline'**
  String get actionTimeline;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get actionCopyText;

  /// No description provided for @actionCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get actionCopyPath;

  /// No description provided for @actionOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOK;

  /// No description provided for @selectionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get selectionCopy;

  /// No description provided for @selectionCitation.
  ///
  /// In en, this message translates to:
  /// **'Citation'**
  String get selectionCitation;

  /// No description provided for @selectionDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get selectionDictionary;

  /// No description provided for @selectionCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get selectionCharacter;

  /// No description provided for @selectionLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get selectionLink;

  /// No description provided for @selectionNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get selectionNote;

  /// No description provided for @selectionTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get selectionTranslate;

  /// No description provided for @selectionCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get selectionCopied;

  /// No description provided for @selectionSavedCitation.
  ///
  /// In en, this message translates to:
  /// **'Saved citation'**
  String get selectionSavedCitation;

  /// No description provided for @selectionAddedToDictionary.
  ///
  /// In en, this message translates to:
  /// **'Added to dictionary'**
  String get selectionAddedToDictionary;

  /// No description provided for @selectionSavedCharacter.
  ///
  /// In en, this message translates to:
  /// **'Saved character description'**
  String get selectionSavedCharacter;

  /// No description provided for @selectionLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get selectionLinked;

  /// No description provided for @selectionLinkOpenBookFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a book to link'**
  String get selectionLinkOpenBookFirst;

  /// No description provided for @selectionNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added'**
  String get selectionNoteAdded;

  /// No description provided for @selectionTranslateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open translator'**
  String get selectionTranslateFailed;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsAppearanceFollowSystem;

  /// No description provided for @settingsAppearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// No description provided for @settingsAppearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// No description provided for @settingsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsLibrary;

  /// No description provided for @settingsShowDocuments.
  ///
  /// In en, this message translates to:
  /// **'Show documents'**
  String get settingsShowDocuments;

  /// No description provided for @settingsShowDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include PDFs and TXT files alongside books'**
  String get settingsShowDocumentsSubtitle;

  /// No description provided for @settingsReader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get settingsReader;

  /// No description provided for @settingsSelectionMenu.
  ///
  /// In en, this message translates to:
  /// **'Selection menu'**
  String get settingsSelectionMenu;

  /// No description provided for @settingsSelectionMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder actions and choose which appear in \"…\"'**
  String get settingsSelectionMenuSubtitle;

  /// No description provided for @settingsSelectionMenuHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. Toggle \"In overflow\" to hide an action behind the \"…\" menu instead of showing it inline.'**
  String get settingsSelectionMenuHint;

  /// No description provided for @settingsSelectionMenuInOverflow.
  ///
  /// In en, this message translates to:
  /// **'In overflow'**
  String get settingsSelectionMenuInOverflow;

  /// No description provided for @settingsSelectionMenuResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsSelectionMenuResetTooltip;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSupportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported formats'**
  String get settingsSupportedFormats;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageSwedish;

  /// No description provided for @libraryAddBooks.
  ///
  /// In en, this message translates to:
  /// **'Add books'**
  String get libraryAddBooks;

  /// No description provided for @libraryScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan device for books'**
  String get libraryScanTooltip;

  /// No description provided for @libraryRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh covers & metadata'**
  String get libraryRefreshTooltip;

  /// No description provided for @libraryRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing covers & metadata…'**
  String get libraryRefreshing;

  /// No description provided for @libraryRefreshAllHave.
  ///
  /// In en, this message translates to:
  /// **'All books already have metadata.'**
  String get libraryRefreshAllHave;

  /// No description provided for @libraryRefreshDone.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {n} book(s).'**
  String libraryRefreshDone(int n);

  /// No description provided for @libraryRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String libraryRefreshFailed(String error);

  /// No description provided for @libraryScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning device for books…'**
  String get libraryScanning;

  /// No description provided for @libraryScanNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No new books found.'**
  String get libraryScanNoneFound;

  /// No description provided for @libraryScanAdded.
  ///
  /// In en, this message translates to:
  /// **'Found and added {n} book(s).'**
  String libraryScanAdded(int n);

  /// No description provided for @libraryScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String libraryScanFailed(String error);

  /// No description provided for @libraryImportNone.
  ///
  /// In en, this message translates to:
  /// **'No new books added.'**
  String get libraryImportNone;

  /// No description provided for @libraryImportAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {n} book(s).'**
  String libraryImportAdded(int n);

  /// No description provided for @libraryImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String libraryImportFailed(String error);

  /// No description provided for @libraryGroupOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get libraryGroupOther;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No books yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to import books, or use the scan icon to find books on your device.'**
  String get libraryEmptyHint;

  /// No description provided for @librarySeriesBooksCount.
  ///
  /// In en, this message translates to:
  /// **'{n} book(s) in series'**
  String librarySeriesBooksCount(int n);

  /// No description provided for @libraryConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from library?'**
  String get libraryConfirmDeleteTitle;

  /// No description provided for @libraryConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Removes this book and all its annotations.'**
  String get libraryConfirmDeleteBody;

  /// No description provided for @citationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No citations yet'**
  String get citationsEmptyTitle;

  /// No description provided for @citationsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a passage in the reader and tap \"Citation\" to save it here.'**
  String get citationsEmptyHint;

  /// No description provided for @citationsCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get citationsCopiedToClipboard;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a passage in the reader, tap \"…\" then \"Note\" to attach a thought.'**
  String get notesEmptyHint;

  /// No description provided for @notesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get notesAdd;

  /// No description provided for @notesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get notesEdit;

  /// No description provided for @notesPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get notesPromptHint;

  /// No description provided for @charactersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No characters yet'**
  String get charactersEmptyTitle;

  /// No description provided for @charactersEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'In the reader, long-press a passage that describes a character and tap \"Character\".'**
  String get charactersEmptyHint;

  /// No description provided for @charactersUnaffiliated.
  ///
  /// In en, this message translates to:
  /// **'Unaffiliated'**
  String get charactersUnaffiliated;

  /// No description provided for @charactersDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete character'**
  String get charactersDeleteTooltip;

  /// No description provided for @charactersTimelineTooltip.
  ///
  /// In en, this message translates to:
  /// **'View timeline'**
  String get charactersTimelineTooltip;

  /// No description provided for @charactersDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String charactersDeleteTitle(String name);

  /// No description provided for @charactersDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the character and every saved description.'**
  String get charactersDeleteBody;

  /// No description provided for @charactersAddToCharacter.
  ///
  /// In en, this message translates to:
  /// **'Add to character'**
  String get charactersAddToCharacter;

  /// No description provided for @charactersEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter the character\'s name.'**
  String get charactersEnterName;

  /// No description provided for @charactersCreateError.
  ///
  /// In en, this message translates to:
  /// **'Could not create character: {error}'**
  String charactersCreateError(String error);

  /// No description provided for @charactersAliasesLabel.
  ///
  /// In en, this message translates to:
  /// **'a.k.a. {names}'**
  String charactersAliasesLabel(String names);

  /// No description provided for @charactersNoDescriptions.
  ///
  /// In en, this message translates to:
  /// **'No descriptions saved yet.'**
  String get charactersNoDescriptions;

  /// No description provided for @charactersRevealSpoilers.
  ///
  /// In en, this message translates to:
  /// **'Reveal {n} spoiler(s) ahead of you'**
  String charactersRevealSpoilers(int n);

  /// No description provided for @charactersScopeToSeries.
  ///
  /// In en, this message translates to:
  /// **'Scope to series'**
  String get charactersScopeToSeries;

  /// No description provided for @charactersTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} — timeline'**
  String charactersTimelineTitle(String name);

  /// No description provided for @charactersTimelineBookLabel.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get charactersTimelineBookLabel;

  /// No description provided for @charactersTimelineNoEpub.
  ///
  /// In en, this message translates to:
  /// **'No EPUB books found in this character\'s series.'**
  String get charactersTimelineNoEpub;

  /// No description provided for @charactersTimelineNotMentioned.
  ///
  /// In en, this message translates to:
  /// **'{name} is not mentioned in this book.'**
  String charactersTimelineNotMentioned(String name);

  /// No description provided for @charactersTimelineEpubOnly.
  ///
  /// In en, this message translates to:
  /// **'Timeline available for EPUB only.'**
  String get charactersTimelineEpubOnly;

  /// No description provided for @charactersTimelineMentions.
  ///
  /// In en, this message translates to:
  /// **'{n} mention(s)'**
  String charactersTimelineMentions(int n);

  /// No description provided for @dictionariesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No dictionaries yet'**
  String get dictionariesEmptyTitle;

  /// No description provided for @dictionariesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a word in the reader and tap \"Dictionary\" to save its definition.'**
  String get dictionariesEmptyHint;

  /// No description provided for @dictionariesAddDictionary.
  ///
  /// In en, this message translates to:
  /// **'Create dictionary'**
  String get dictionariesAddDictionary;

  /// No description provided for @dictionariesDictionaryName.
  ///
  /// In en, this message translates to:
  /// **'Dictionary name'**
  String get dictionariesDictionaryName;

  /// No description provided for @dictionariesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get dictionariesDescription;

  /// No description provided for @dictionariesNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet.'**
  String get dictionariesNoEntries;

  /// No description provided for @linksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get linksEmptyTitle;

  /// No description provided for @linksEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a passage in the reader and tap \"Link\" to point at another book in your library.'**
  String get linksEmptyHint;

  /// No description provided for @linksTabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get linksTabList;

  /// No description provided for @linksTabGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get linksTabGraph;

  /// No description provided for @linksOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source book'**
  String get linksOpenSource;

  /// No description provided for @linksOpenTarget.
  ///
  /// In en, this message translates to:
  /// **'Open target book'**
  String get linksOpenTarget;

  /// No description provided for @linksGraphEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links yet — add some from the reader\'s selection menu first.'**
  String get linksGraphEmpty;

  /// No description provided for @linksPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Link to book'**
  String get linksPickerTitle;

  /// No description provided for @linksPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title or author'**
  String get linksPickerSearchHint;

  /// No description provided for @linksPickerNoOthers.
  ///
  /// In en, this message translates to:
  /// **'No other books in your library'**
  String get linksPickerNoOthers;

  /// No description provided for @linksPickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get linksPickerNoMatches;

  /// No description provided for @linksSheetFromBook.
  ///
  /// In en, this message translates to:
  /// **'Links from this book'**
  String get linksSheetFromBook;

  /// No description provided for @linksSheetToBook.
  ///
  /// In en, this message translates to:
  /// **'Links to this book'**
  String get linksSheetToBook;

  /// No description provided for @linksSheetNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No links'**
  String get linksSheetNoLinks;

  /// No description provided for @statsTabDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statsTabDay;

  /// No description provided for @statsTabWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsTabWeek;

  /// No description provided for @statsTabMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsTabMonth;

  /// No description provided for @statsTabAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get statsTabAllTime;

  /// No description provided for @statsCardPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get statsCardPages;

  /// No description provided for @statsCardWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get statsCardWords;

  /// No description provided for @statsCardPagesPerHour.
  ///
  /// In en, this message translates to:
  /// **'Pages / hour'**
  String get statsCardPagesPerHour;

  /// No description provided for @statsCardWordsPerHour.
  ///
  /// In en, this message translates to:
  /// **'Words / hour'**
  String get statsCardWordsPerHour;

  /// No description provided for @statsCardBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get statsCardBooks;

  /// No description provided for @statsCardBooksFinished.
  ///
  /// In en, this message translates to:
  /// **'finished'**
  String get statsCardBooksFinished;

  /// No description provided for @statsCardActiveReading.
  ///
  /// In en, this message translates to:
  /// **'active reading'**
  String get statsCardActiveReading;

  /// No description provided for @statsCaptionLast24h.
  ///
  /// In en, this message translates to:
  /// **'last 24h'**
  String get statsCaptionLast24h;

  /// No description provided for @statsCaptionLast7d.
  ///
  /// In en, this message translates to:
  /// **'last 7 days'**
  String get statsCaptionLast7d;

  /// No description provided for @statsCaptionLast30d.
  ///
  /// In en, this message translates to:
  /// **'last 30 days'**
  String get statsCaptionLast30d;

  /// No description provided for @statsCaptionAllTime.
  ///
  /// In en, this message translates to:
  /// **'all time'**
  String get statsCaptionAllTime;

  /// No description provided for @statsEmptyForRange.
  ///
  /// In en, this message translates to:
  /// **'No reading recorded {caption} yet.'**
  String statsEmptyForRange(String caption);

  /// No description provided for @statsFinishedSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Finished books'**
  String get statsFinishedSheetTitle;

  /// No description provided for @statsMarkAsNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Mark as not finished'**
  String get statsMarkAsNotFinished;

  /// No description provided for @backupExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExportButton;

  /// No description provided for @backupRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestoreButton;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Export bundles your library files, covers, database (books, citations, characters, dictionary, progress) and reader settings into a single .zip you can share or save off-device.'**
  String get backupIntro;

  /// No description provided for @backupRestoreFooter.
  ///
  /// In en, this message translates to:
  /// **'Restoring overwrites all current data. The app must be closed and reopened afterwards for the change to take effect.'**
  String get backupRestoreFooter;

  /// No description provided for @backupReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all data?'**
  String get backupReplaceTitle;

  /// No description provided for @backupReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'Restoring will permanently overwrite your current library, citations, characters, dictionary, and reader settings with the contents of the backup. This cannot be undone.'**
  String get backupReplaceBody;

  /// No description provided for @backupRestoreCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get backupRestoreCompleteTitle;

  /// No description provided for @backupRestoreCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Restored {n} files{takenAt}\n\nClose and reopen the app to load the restored data.'**
  String backupRestoreCompleteBody(int n, String takenAt);

  /// No description provided for @backupTakenAtSuffix.
  ///
  /// In en, this message translates to:
  /// **'\nBackup taken {at}'**
  String backupTakenAtSuffix(String at);

  /// No description provided for @backupWrittenTo.
  ///
  /// In en, this message translates to:
  /// **'Backup written to {path}'**
  String backupWrittenTo(String path);

  /// No description provided for @backupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String backupExportFailed(String error);

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String backupRestoreFailed(String error);

  /// No description provided for @backupPermissionWarning.
  ///
  /// In en, this message translates to:
  /// **'Storage permission denied — backup will be saved in app-private storage and will only be accessible via Share.'**
  String get backupPermissionWarning;

  /// No description provided for @bundleShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share book bundle'**
  String get bundleShareTitle;

  /// No description provided for @bundleShareDescription.
  ///
  /// In en, this message translates to:
  /// **'Bundles \"{label}\"{suffix} together with citations, notes, characters, dictionary entries, and links into a single .zip you can share.'**
  String bundleShareDescription(String label, String suffix);

  /// No description provided for @bundleSeriesSuffix.
  ///
  /// In en, this message translates to:
  /// **' ({count} books)'**
  String bundleSeriesSuffix(int count);

  /// No description provided for @bundleIncludeLinkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Include linked books'**
  String get bundleIncludeLinkedTitle;

  /// No description provided for @bundleIncludeLinkedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recursively pull in every book reachable through links'**
  String get bundleIncludeLinkedSubtitle;

  /// No description provided for @bundleIncludeProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Include reading progress'**
  String get bundleIncludeProgressTitle;

  /// No description provided for @bundleIncludeProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default — useful when sharing with friends'**
  String get bundleIncludeProgressSubtitle;

  /// No description provided for @bundleSubject.
  ///
  /// In en, this message translates to:
  /// **'Book bundle: {title}'**
  String bundleSubject(String title);

  /// No description provided for @bundleSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Bundle saved to {path}'**
  String bundleSavedTo(String path);

  /// No description provided for @bundleExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String bundleExportFailed(String error);

  /// No description provided for @importBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'Import bundle'**
  String get importBundleTitle;

  /// No description provided for @importBundleIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a .zip bundle exported from another Lorekeeper install. Existing books with the same title, author, and size are merged in place; otherwise a copy is added to your library.'**
  String get importBundleIntro;

  /// No description provided for @importBundlePick.
  ///
  /// In en, this message translates to:
  /// **'Pick bundle file'**
  String get importBundlePick;

  /// No description provided for @importBundleProgressIncluded.
  ///
  /// In en, this message translates to:
  /// **'Includes reading progress — your last-read positions will be replaced for matching books.'**
  String get importBundleProgressIncluded;

  /// No description provided for @importBundleBooksHeader.
  ///
  /// In en, this message translates to:
  /// **'Books in bundle:'**
  String get importBundleBooksHeader;

  /// No description provided for @importBundleSummary.
  ///
  /// In en, this message translates to:
  /// **'Imported {added} new book(s) ({merged} matched existing). {citations} citations, {notes} notes, {chars} characters, {dicts} dict entries, {links} links.'**
  String importBundleSummary(int added, int merged, int citations, int notes,
      int chars, int dicts, int links);

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Download books'**
  String get downloadsTitle;

  /// No description provided for @downloadsKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'RapidAPI key not set. Edit lib/features/downloads/services/anna_archive_api.dart and paste your key into _rapidApiKey, or run with --dart-define=RAPIDAPI_KEY=…'**
  String get downloadsKeyMissing;

  /// No description provided for @readerWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get readerWorking;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

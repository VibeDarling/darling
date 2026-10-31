/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef PREFERENCES_PSCONSTANTS_H
#define PREFERENCES_PSCONSTANTS_H

#import <Foundation/Foundation.h>

/* The keys of a specifier's properties, which are also its plist keys. */
extern NSString *const PSIDKey;                       // id
extern NSString *const PSCellClassKey;                // cell
extern NSString *const PSTableCellClassKey;           // cellClass
extern NSString *const PSTableCellKey;                // cellObject
extern NSString *const PSTableCellHeightKey;          // height
extern NSString *const PSTableCellUseEtchedAppearanceKey;
extern NSString *const PSTitleKey;                    // label
extern NSString *const PSDefaultsKey;                 // defaults
extern NSString *const PSKeyNameKey;                  // key
extern NSString *const PSDefaultValueKey;             // default
extern NSString *const PSValueKey;                    // value
extern NSString *const PSValidValuesKey;              // validValues
extern NSString *const PSValidTitlesKey;              // validTitles
extern NSString *const PSShortTitlesKey;              // shortTitles
extern NSString *const PSValuesDataSourceKey;         // valuesDataSource
extern NSString *const PSTitlesDataSourceKey;         // titlesDataSource
extern NSString *const PSControlMinimumKey;           // min
extern NSString *const PSControlMaximumKey;           // max
extern NSString *const PSControlIsLoadingKey;
extern NSString *const PSControlKey;                  // control
extern NSString *const PSSliderShowValueKey;          // showValue
extern NSString *const PSSliderIsSegmented;           // isSegmented
extern NSString *const PSSliderSegmentCount;          // segmentCount
extern NSString *const PSValueChangedNotificationKey; // PostNotification
extern NSString *const PSButtonActionKey;             // action
extern NSString *const PSActionKey;                   // action
extern NSString *const PSConfirmationKey;             // confirmation
extern NSString *const PSFooterTextGroupKey;          // footerText
extern NSString *const PSFooterAlignmentGroupKey;     // footerAlignment
extern NSString *const PSFooterCellClassGroupKey;     // footerCellClass
extern NSString *const PSHeaderCellClassGroupKey;     // headerCellClass
extern NSString *const PSIsRadioGroupKey;             // isRadioGroup
extern NSString *const PSRadioGroupCheckedSpecifierKey;
extern NSString *const PSEnabledKey;                  // enabled
extern NSString *const PSIconImageKey;                // iconImage
extern NSString *const PSIconImageShouldFlipForRightToLeftKey;
extern NSString *const PSLazyIconLoading;             // useLazyIcons
extern NSString *const PSSetterKey;                   // set
extern NSString *const PSGetterKey;                   // get
extern NSString *const PSDetailControllerClassKey;    // detail
extern NSString *const PSEditPaneClassKey;            // pane
extern NSString *const PSLazilyLoadedBundleKey;       // lazy-bundle
extern NSString *const PSBundlePathKey;               // bundle
extern NSString *const PSBundleIsControllerKey;       // isController
extern NSString *const PSBundleHasIconKey;            // hasIcon
extern NSString *const PSKeyboardTypeKey;             // keyboard
extern NSString *const PSAutoCapsKey;                 // autoCaps
extern NSString *const PSNoAutoCorrectKey;            // noAutoCorrect
extern NSString *const PSIsSecureKey;                 // isSecure
extern NSString *const PSPlaceholderKey;              // placeholder
extern NSString *const PSAlignmentKey;                // alignment
extern NSString *const PSCopyableCellKey;             // isCopyable
extern NSString *const PSStaticTextMessageKey;        // staticTextMessage
extern NSString *const PSPrioritizeValueTextDisplayKey;
extern NSString *const PSTextViewBottomMarginKey;

/* The plist's own keys around its items. */
extern NSString *const PSSpecifiersKey;               // items
extern NSString *const PSTitleTableKey;               // title

#endif /* PREFERENCES_PSCONSTANTS_H */

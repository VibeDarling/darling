/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * iOS's settings framework, as the Settings app and tweak preference
 * bundles (PreferenceLoader) use it. A reimplementation: Apple's isn't ours
 * to ship.
 */

#import <Preferences/PSConstants.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSViewController.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSTableCell.h>

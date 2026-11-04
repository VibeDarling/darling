/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _GraphicsServices_H_
#define _GraphicsServices_H_

/* GraphicsServices exists so that apps which link it load. It exports
   nothing.

   Provenance (rung 5, demand analysis): Cydia's executable lists
   /System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices
   among its dylibs (llvm-otool -L) but binds no symbol from it
   (llvm-nm -u -m), and Cydia's makefile links -framework GraphicsServices.
   Cydia's source (MobileCydia.mm) looks up one GraphicsServices function
   with dlsym, and only where kCFCoreFoundationVersionNumber < 800; Darling's
   Core Foundation is newer, so Cydia takes its other branch. No other guest
   examined links the framework. VibeDarling issue #460 (an upstream
   demand scan of macOS stock apps, 2026-09-23) also finds Maps, Clock and
   News loading this path, Maps importing one symbol from it; that symbol
   is not implemented here and stays tracked there. A strong bind to a symbol this framework
   does not export aborts in dyld, which is the intended loud failure: add
   the symbol then, with its source. */

#endif

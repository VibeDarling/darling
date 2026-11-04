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


#ifndef _RunningBoardServices_H_
#define _RunningBoardServices_H_

/* RunningBoardServices exists so that apps that link it can load. It exports
   nothing.
   Darling's own app-lifecycle interface, which used to be declared here
   under names recalled from Apple's private headers, is DarlingBoard
   (<DarlingBoard/DarlingBoard.h>).

   Provenance (rung 5, demand analysis): none of the iOS guests examined
   (Cydia, Feather, FlappyBird, FileBrowser, Amped-Gibson,
   Amped-AppstackSDK) links this framework (llvm-otool -L). VibeDarling
   issue #572, an upstream scan of macOS stock apps (2026-09-23), finds
   Freeform, Maps, Podcasts and VoiceMemos loading
   /System/Library/PrivateFrameworks/RunningBoardServices.framework/Versions/A/RunningBoardServices,
   so the path is kept. The symbols that issue lists are not implemented
   here and stay tracked there. A strong bind to a symbol this framework
   does not export aborts in dyld, which is the intended loud failure. */

#endif

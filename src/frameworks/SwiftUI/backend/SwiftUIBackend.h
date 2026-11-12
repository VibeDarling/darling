/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* The UIKit side of Darling's SwiftUI: a plain C interface, so the Swift
   module needs neither Foundation nor UIKit's Swift overlays (arm64 has no
   libswiftFoundation). Strings are UTF-8, views are retained UIView
   pointers, and callbacks take the context they were registered with.
   Self-contained on purpose: the Swift build imports it without an SDK. */

#ifndef SWIFTUI_BACKEND_H
#define SWIFTUI_BACKEND_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void *SUIViewRef;
typedef void (*SUICallback)(void *context);
/* x, y, width, height: the host view's safe area, in its own coordinates. */
typedef void (*SUILayoutCallback)(void *context, double x, double y, double width, double height);

/* UIApplicationMain with an internal delegate; launched() runs from
   application:didFinishLaunchingWithOptions:. Does not return. */
int SUIApplicationMain(int argc, char **argv, SUICallback launched, void *context);
/* A window with a view controller whose view is the returned host view.
   layout() runs whenever the host lays out (size or safe area change). */
SUIViewRef SUIHostCreate(SUILayoutCallback layout, void *context);
/* Runs callback on the main queue, after the current event. */
void SUIRunOnMainQueue(SUICallback callback, void *context);
void SUILog(const char *message);
/* Nonzero when DARLING_SWIFTUI_DEBUG is set: the renderer then logs every
   frame it sets, in window coordinates. */
int SUIDebugEnabled(void);

/* Views. Each Create returns a +1 reference; SUIViewRelease removes the view
   from its superview and drops that reference. */
SUIViewRef SUIViewCreate(void);
SUIViewRef SUILabelCreate(void);
/* A transparent control on top of a button's label; a tap inside calls
   action, and while it is pressed its sibling views are dimmed. */
SUIViewRef SUITapControlCreate(SUICallback action, void *context);
void SUIViewRelease(SUIViewRef view);
/* Makes parent's subviews exactly children[0..count) in that order (back to
   front), adding or reordering as needed; others are left in place. */
void SUIViewSetSubviews(SUIViewRef parent, SUIViewRef *children, int count);
void SUIViewSetFrame(SUIViewRef view, double x, double y, double width, double height);
void SUIViewSetBackgroundColor(SUIViewRef view, double red, double green, double blue, double alpha);
void SUIViewSetAlpha(SUIViewRef view, double alpha);

/* weight: 100 (ultra light) .. 900 (black), as in CSS. */
void SUILabelSetText(SUIViewRef label, const char *utf8);
void SUILabelSetFont(SUIViewRef label, double size, int weight, int italic);
void SUILabelSetTextColor(SUIViewRef label, double red, double green, double blue, double alpha);
/* 0 leading, 1 center, 2 trailing. */
void SUILabelSetAlignment(SUIViewRef label, int alignment);
/* 0: as many lines as needed. */
void SUILabelSetLineLimit(SUIViewRef label, int lines);
/* The label's text size when wrapped at maxWidth (a huge value for one line). */
void SUILabelMeasure(SUIViewRef label, double maxWidth, double *width, double *height);

#ifdef __cplusplus
}
#endif

#endif

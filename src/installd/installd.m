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

/*
 * installd: installs the app an itms-services:// URL describes, the way
 * alternative app stores (Feather, AltStore's server mode) install on iOS.
 *
 *   itms-services://?action=download-manifest&url=<manifest>
 *
 * The manifest is a plist whose first item names the IPA (an asset of kind
 * software-package). Its Payload/X.app goes to /Applications, replacing an
 * installed app with the same bundle identifier. frontboardd starts one
 * installd per URL.
 *
 * Progress, 0 to 1, is written to /private/var/installd/Progress/<bundle
 * identifier>, which LSApplicationWorkspace's installProgressForBundleID:
 * reads; the file is removed once the app is in place. A store takes the
 * file's removal for success, so it stays when the install fails.
 */

#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <spawn.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

static NSString *const IDApplications = @"/Applications";
static NSString *const IDProgress = @"/private/var/installd/Progress";
static NSString *const IDStaging = @"/private/var/installd/Staging";

static void IDLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	fprintf(stderr, "installd: %s\n", [message UTF8String]);
}

static int IDRun(NSArray<NSString *> *arguments)
{
	char **argv = calloc([arguments count] + 1, sizeof(char *));
	for (NSUInteger i = 0; i < [arguments count]; i++)
		argv[i] = (char *)[arguments[i] fileSystemRepresentation];
	extern char **environ;
	pid_t pid;
	int rc = posix_spawn(&pid, argv[0], NULL, NULL, argv, environ);
	free(argv);
	if (rc != 0) {
		IDLog(@"cannot run %@: %s", arguments[0], strerror(rc));
		return -1;
	}
	int status;
	while (waitpid(pid, &status, 0) < 0 && errno == EINTR)
		;
	return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

typedef enum { IDHostRemote, IDHostLoopback, IDHostUnknown } IDHostKind;

static IDHostKind IDHost(NSString *host)
{
	struct addrinfo *list;
	if ([host length] == 0 || getaddrinfo([host UTF8String], NULL, NULL, &list) != 0)
		return IDHostUnknown;
	IDHostKind kind = IDHostLoopback;
	for (struct addrinfo *ai = list; ai != NULL; ai = ai->ai_next) {
		if (ai->ai_family == AF_INET) {
			in_addr_t addr = ntohl(((struct sockaddr_in *)ai->ai_addr)->sin_addr.s_addr);
			if ((addr >> 24) != 127)
				kind = IDHostRemote;
		} else if (ai->ai_family == AF_INET6) {
			if (!IN6_IS_ADDR_LOOPBACK(&((struct sockaddr_in6 *)ai->ai_addr)->sin6_addr))
				kind = IDHostRemote;
		}
	}
	freeaddrinfo(list);
	return kind;
}

/* A store on this device serves itself under a public name for 127.0.0.1:
   Feather's is *.backloop.dev, wildcard and all. Routers that guard against
   DNS rebinding drop such answers, so a name that does not resolve is taken
   to be this device. Its certificate is the store's business (Feather's may
   have expired), and it may serve plain HTTP when it has none. */
static BOOL IDDownload(NSURL *url, NSString *destination)
{
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
	IDHostKind kind = IDHost([components host]);
	if (kind == IDHostUnknown) {
		IDLog(@"%@ does not resolve; fetching from this device", [components host]);
		[components setHost:@"127.0.0.1"];
	}
	NSMutableArray *arguments = [@[ @"/usr/bin/curl", @"-fsSL", @"--retry", @"2", @"-o", destination ] mutableCopy];
	if (kind != IDHostRemote)
		[arguments addObject:@"-k"];
	if (IDRun([arguments arrayByAddingObject:[[components URL] absoluteString]]) == 0)
		return YES;
	if (kind != IDHostRemote && [[components scheme] isEqualToString:@"https"]) {
		[components setScheme:@"http"];
		IDLog(@"retrying %@ over HTTP", [components URL]);
		return IDRun([arguments arrayByAddingObject:[[components URL] absoluteString]]) == 0;
	}
	return NO;
}

static void IDSetProgress(NSString *identifier, double value)
{
	if ([identifier length] == 0 || [identifier rangeOfString:@"/"].location != NSNotFound)
		return;
	[[NSFileManager defaultManager] createDirectoryAtPath:IDProgress withIntermediateDirectories:YES attributes:nil error:NULL];
	[[NSString stringWithFormat:@"%.3f", value] writeToFile:[IDProgress stringByAppendingPathComponent:identifier]
		atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void IDClearProgress(NSString *identifier)
{
	if ([identifier length] > 0 && [identifier rangeOfString:@"/"].location == NSNotFound)
		[[NSFileManager defaultManager] removeItemAtPath:[IDProgress stringByAppendingPathComponent:identifier] error:NULL];
}

static NSString *IDBundleIdentifier(NSString *app)
{
	NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Info.plist"]];
	id identifier = info[@"CFBundleIdentifier"];
	return [identifier isKindOfClass:[NSString class]] ? identifier : nil;
}

/* IPAs often carry no Unix modes, so executables are known by their header. */
static void IDMarkExecutables(NSString *app)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *walk = [fm enumeratorAtPath:app];
	for (NSString *relative in walk) {
		if (![[walk fileAttributes][NSFileType] isEqualToString:NSFileTypeRegular])
			continue;
		NSString *path = [app stringByAppendingPathComponent:relative];
		FILE *file = fopen([path fileSystemRepresentation], "rb");
		if (file == NULL)
			continue;
		unsigned char m[4];
		size_t got = fread(m, 1, 4, file);
		fclose(file);
		if (got != 4)
			continue;
		uint32_t magic = (uint32_t)m[0] << 24 | (uint32_t)m[1] << 16 | (uint32_t)m[2] << 8 | m[3];
		if (magic == 0xcffaedfe || magic == 0xcefaedfe || magic == 0xcafebabe || magic == 0xfeedfacf)
			chmod([path fileSystemRepresentation], 0755);
	}
}

/* Installed apps with this identifier, at the top of /Applications or one
   directory deeper, in a container. */
static NSArray<NSString *> *IDInstalledCopies(NSString *identifier)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *copies = [NSMutableArray array];
	for (NSString *entry in [fm contentsOfDirectoryAtPath:IDApplications error:NULL]) {
		NSString *path = [IDApplications stringByAppendingPathComponent:entry];
		if ([[entry pathExtension] isEqualToString:@"app"]) {
			if ([IDBundleIdentifier(path) isEqualToString:identifier])
				[copies addObject:path];
			continue;
		}
		for (NSString *inner in [fm contentsOfDirectoryAtPath:path error:NULL]) {
			NSString *app = [path stringByAppendingPathComponent:inner];
			if ([[inner pathExtension] isEqualToString:@"app"] && [IDBundleIdentifier(app) isEqualToString:identifier])
				[copies addObject:path];
		}
	}
	return copies;
}

static BOOL IDInstall(NSString *ipa, NSString *staging, NSString **installedIdentifier)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *unpacked = [staging stringByAppendingPathComponent:@"unpacked"];
	[fm createDirectoryAtPath:unpacked withIntermediateDirectories:YES attributes:nil error:NULL];
	// bsdtar reads zip files, and refuses paths that leave the directory.
	if (IDRun(@[ @"/usr/bin/bsdtar", @"-xf", ipa, @"-C", unpacked, @"Payload" ]) != 0) {
		IDLog(@"cannot unpack the IPA");
		return NO;
	}
	NSString *payload = [unpacked stringByAppendingPathComponent:@"Payload"];
	NSArray *apps = [[fm contentsOfDirectoryAtPath:payload error:NULL] filteredArrayUsingPredicate:
		[NSPredicate predicateWithFormat:@"pathExtension == 'app'"]];
	if ([apps count] != 1) {
		IDLog(@"the IPA holds %lu apps, not one", (unsigned long)[apps count]);
		return NO;
	}
	NSString *name = apps[0];
	NSString *app = [payload stringByAppendingPathComponent:name];
	NSString *identifier = IDBundleIdentifier(app);
	if (identifier == nil) {
		IDLog(@"%@ has no bundle identifier", name);
		return NO;
	}
	*installedIdentifier = identifier;
	IDSetProgress(identifier, 0.8);
	IDMarkExecutables(app);

	for (NSString *old in IDInstalledCopies(identifier)) {
		IDLog(@"replacing %@", old);
		[fm removeItemAtPath:old error:NULL];
	}
	// Another app has the name: this one goes in a container of its own.
	NSString *destination = [IDApplications stringByAppendingPathComponent:name];
	if ([fm fileExistsAtPath:destination]) {
		NSString *container = [IDApplications stringByAppendingPathComponent:identifier];
		[fm createDirectoryAtPath:container withIntermediateDirectories:YES attributes:nil error:NULL];
		destination = [container stringByAppendingPathComponent:name];
	}
	NSError *error = nil;
	if (![fm moveItemAtPath:app toPath:destination error:&error]) {
		IDLog(@"cannot move %@ into place: %@", name, error);
		return NO;
	}
	IDLog(@"installed %@ (%@) at %@", name, identifier, destination);
	return YES;
}

int main(int argc, char **argv)
{
	@autoreleasepool {
		if (argc != 2) {
			fprintf(stderr, "usage: installd itms-services://?action=download-manifest&url=<manifest>\n");
			return 2;
		}
		NSURLComponents *request = [NSURLComponents componentsWithString:@(argv[1])];
		NSString *action = nil, *manifestString = nil;
		for (NSURLQueryItem *item in [request queryItems]) {
			if ([[item name] isEqualToString:@"action"])
				action = [item value];
			else if ([[item name] isEqualToString:@"url"])
				manifestString = [item value];
		}
		if (![[[request scheme] lowercaseString] isEqualToString:@"itms-services"]
			|| ![action isEqualToString:@"download-manifest"] || manifestString == nil) {
			IDLog(@"not an install request: %s", argv[1]);
			return 2;
		}
		NSURL *manifestURL = [NSURL URLWithString:manifestString];
		if (manifestURL == nil || ![@[ @"http", @"https" ] containsObject:[[manifestURL scheme] lowercaseString]]) {
			IDLog(@"bad manifest URL %@", manifestString);
			return 2;
		}

		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *staging = [IDStaging stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
		[fm createDirectoryAtPath:staging withIntermediateDirectories:YES attributes:nil error:NULL];

		int rc = 1;
		NSString *identifier = nil;
		do {
			NSString *manifestPath = [staging stringByAppendingPathComponent:@"manifest.plist"];
			if (!IDDownload(manifestURL, manifestPath)) {
				IDLog(@"cannot fetch the manifest %@", manifestURL);
				break;
			}
			NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
			NSDictionary *item = [manifest[@"items"] isKindOfClass:[NSArray class]] ? [manifest[@"items"] firstObject] : nil;
			NSString *package = nil;
			for (NSDictionary *asset in item[@"assets"])
				if ([asset isKindOfClass:[NSDictionary class]] && [asset[@"kind"] isEqual:@"software-package"])
					package = asset[@"url"];
			NSURL *packageURL = [package isKindOfClass:[NSString class]] ? [NSURL URLWithString:package relativeToURL:manifestURL] : nil;
			if (packageURL == nil) {
				IDLog(@"the manifest names no software-package");
				break;
			}
			identifier = item[@"metadata"][@"bundle-identifier"];
			if (![identifier isKindOfClass:[NSString class]])
				identifier = nil;
			IDLog(@"installing %@ from %@", identifier ?: @"an app", [packageURL absoluteURL]);

			IDSetProgress(identifier, 0.6);
			NSString *ipa = [staging stringByAppendingPathComponent:@"app.ipa"];
			if (!IDDownload([packageURL absoluteURL], ipa)) {
				IDLog(@"cannot fetch the IPA %@", [packageURL absoluteURL]);
				break;
			}
			IDSetProgress(identifier, 0.7);

			NSString *installed = nil;
			if (!IDInstall(ipa, staging, &installed))
				break;
			if (identifier != nil && ![identifier isEqualToString:installed])
				IDClearProgress(identifier);
			identifier = installed;
			IDSetProgress(identifier, 0.9);
			rc = 0;
		} while (0);

		[fm removeItemAtPath:staging error:NULL];
		if (rc == 0) {
			// Long enough for a store polling the progress to see the end.
			sleep(2);
			IDClearProgress(identifier);
		}
		return rc;
	}
}

# Host test: ColorSync device dictionary keys and device class constants
# are defined with correct Apple values and declared in the public header.
# usage: ruby tests/colorsync-device-constants.rb [REPO_ROOT]
require 'tmpdir'
require 'open3'

root = ARGV.fetch(0, File.expand_path('..', __dir__))

EXPECTED = {
  'kColorSyncDeviceProfileURL' => 'DeviceProfileURL',
  'kColorSyncDeviceModeDescriptions' => 'DeviceModeDescriptions',
  'kColorSyncDeviceDefaultProfileID' => 'DeviceDefaultProfileID',
  'kColorSyncDeviceDescriptions' => 'DeviceDescriptions',
  'kColorSyncFactoryProfiles' => 'FactoryProfiles',
  'kColorSyncDeviceUserScope' => 'DeviceUserScope',
  'kColorSyncDeviceHostScope' => 'DeviceHostScope',
  'kColorSyncPrinterDeviceClass' => 'prnt',
  'kColorSyncCustomProfiles' => 'CustomProfiles',
  'kColorSyncDisplayDeviceClass' => 'mntr',
}

colorsync_c_lines = File.readlines("#{root}/src/frameworks/ColorSync/src/ColorSync.c")
colorsync_c = colorsync_c_lines.join
colorsync_h = File.read("#{root}/src/frameworks/ColorSync/include/ColorSync/ColorSync.h")

failed = false

EXPECTED.each do |name, expected_val|
  pattern = /^\s*CFStringRef\s+#{name}\s*=\s*CFSTR\("#{Regexp.escape(expected_val)}"\);/
  unless colorsync_c =~ pattern
    warn "FAIL: #{name} in ColorSync.c expected definition CFSTR(\"#{expected_val}\")"
    failed = true
  end

  decl_pattern = /^\s*extern\s+CFStringRef\s+#{name}\s*;/
  unless colorsync_h =~ decl_pattern
    warn "FAIL: #{name} is not declared as 'extern CFStringRef #{name};' in ColorSync.h"
    failed = true
  end
end

abort 'ColorSync device constants mismatch' if failed

defs = colorsync_c_lines.select { |l| l =~ /^\s*CFStringRef\s+kColorSync\w+\s*=\s*CFSTR\(/ }
abort 'ColorSync.c constant extraction failed' if defs.empty?

Dir.mktmpdir('colorsync-test-') do |tmpdir|
  File.write("#{tmpdir}/cf.h", "typedef const struct __CFString *CFStringRef;\n#define CFSTR(s) ((CFStringRef)(s))\n")
  File.write("#{tmpdir}/colorsync_defs.c", "#include \"cf.h\"\n" + defs.join)

  defs_o = "#{tmpdir}/colorsync_defs.o"
  out, st = Open3.capture2e('clang', '-fPIC', '-c', "#{tmpdir}/colorsync_defs.c", '-o', defs_o)
  abort out unless st.success?

  probe_c = "#{tmpdir}/probe.c"
  File.write(probe_c, <<~'C')
    #include <assert.h>
    #include <stdio.h>
    #include <string.h>

    typedef const struct __CFString *CFStringRef;

    extern CFStringRef kColorSyncDeviceProfileURL;
    extern CFStringRef kColorSyncDeviceModeDescriptions;
    extern CFStringRef kColorSyncDeviceDefaultProfileID;
    extern CFStringRef kColorSyncDeviceDescriptions;
    extern CFStringRef kColorSyncFactoryProfiles;
    extern CFStringRef kColorSyncDeviceUserScope;
    extern CFStringRef kColorSyncDeviceHostScope;
    extern CFStringRef kColorSyncPrinterDeviceClass;
    extern CFStringRef kColorSyncCustomProfiles;
    extern CFStringRef kColorSyncDisplayDeviceClass;

    int main(void) {
        assert(strcmp((const char *)kColorSyncDeviceProfileURL, "DeviceProfileURL") == 0);
        assert(strcmp((const char *)kColorSyncDeviceModeDescriptions, "DeviceModeDescriptions") == 0);
        assert(strcmp((const char *)kColorSyncDeviceDefaultProfileID, "DeviceDefaultProfileID") == 0);
        assert(strcmp((const char *)kColorSyncDeviceDescriptions, "DeviceDescriptions") == 0);
        assert(strcmp((const char *)kColorSyncFactoryProfiles, "FactoryProfiles") == 0);
        assert(strcmp((const char *)kColorSyncDeviceUserScope, "DeviceUserScope") == 0);
        assert(strcmp((const char *)kColorSyncDeviceHostScope, "DeviceHostScope") == 0);
        assert(strcmp((const char *)kColorSyncPrinterDeviceClass, "prnt") == 0);
        assert(strcmp((const char *)kColorSyncCustomProfiles, "CustomProfiles") == 0);
        assert(strcmp((const char *)kColorSyncDisplayDeviceClass, "mntr") == 0);

        CFStringRef all[] = {
            kColorSyncDeviceProfileURL,
            kColorSyncDeviceModeDescriptions,
            kColorSyncDeviceDefaultProfileID,
            kColorSyncDeviceDescriptions,
            kColorSyncFactoryProfiles,
            kColorSyncDeviceUserScope,
            kColorSyncDeviceHostScope,
            kColorSyncPrinterDeviceClass,
            kColorSyncCustomProfiles,
            kColorSyncDisplayDeviceClass,
        };
        int count = sizeof(all) / sizeof(all[0]);
        for (int i = 0; i < count; i++) {
            for (int j = i + 1; j < count; j++) {
                assert(all[i] != all[j]);
                assert(strcmp((const char *)all[i], (const char *)all[j]) != 0);
            }
        }

        puts("PASS: ColorSync device constants verified via extracted object");
        return 0;
    }
  C

  probe_bin = "#{tmpdir}/probe"
  out, st = Open3.capture2e('clang', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', probe_c, defs_o, '-o', probe_bin)
  abort out unless st.success?

  out, st = Open3.capture2e(probe_bin)
  abort out unless st.success?
end

puts 'PASS: all ColorSync device constants defined and declared correctly'

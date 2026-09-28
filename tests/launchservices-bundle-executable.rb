#!/usr/bin/env ruby
# Host control-flow probe: actual resolver, real stat, controlled CF objects.
# Does not test CoreFoundation's bundle parser or launch a Darling process.
require 'tmpdir'
require 'fileutils'

source = File.read(File.expand_path('../src/frameworks/CoreServices/src/LaunchServices/LaunchServices.cpp', __dir__))
resolver = source[/static OSStatus resolveApplicationExecutable\(.*?\n\}\n/m] or abort 'resolver missing'
abort 'resolver must precede argv construction' unless source.match?(/FSRefMakePath\(appParams->application, exePath\).*?rv = resolveApplicationExecutable\(exePath\);.*?if \(rv != noErr\)\s*return rv;.*?if \(appParams->argv/m)

Dir.mktmpdir('ls-bundle-') do |dir|
  FileUtils.mkdir_p("#{dir}/Sample é.app/Contents/MacOS")
  File.write("#{dir}/Sample é.app/Contents/MacOS/Runner", '')
  File.write("#{dir}/plain", '')
  File.symlink("#{dir}/Sample é.app", "#{dir}/link.app")
  code = <<~'CPP'
    #include <cassert>
    #include <cerrno>
    #include <cstring>
    #include <string>
    #include <limits.h>
    #include <sys/stat.h>
    using OSStatus = int;
    using UInt8 = unsigned char;
    using Boolean = bool;
    constexpr int noErr = 0, kLSNoExecutableErr = -10827;
    constexpr void* kCFAllocatorDefault = nullptr;
    static int makeOSStatus(int error) { return -error; }
    struct Object { std::string path; int kind; };
    using CFURLRef = Object*;
    using CFBundleRef = Object*;
    static int failAt, calls, created, released, live;
    static std::string selected;
    static Object* create(std::string path, int kind) {
      ++calls;
      if (calls == failAt) return nullptr;
      ++created; ++live;
      return new Object{path, kind};
    }
    static CFURLRef CFURLCreateFromFileSystemRepresentation(void*, const UInt8* path, size_t n, bool directory) {
      assert(directory);
      return create(std::string(reinterpret_cast<const char*>(path), n), 1);
    }
    static CFBundleRef CFBundleCreate(void*, CFURLRef url) {
      assert(url && url->kind == 1);
      return create(url->path, 2);
    }
    static CFURLRef CFBundleCopyExecutableURL(CFBundleRef bundle) {
      assert(bundle && bundle->kind == 2);
      return create(selected, 3);
    }
    static bool CFURLGetFileSystemRepresentation(CFURLRef url, bool absolute, UInt8* path, size_t size) {
      assert(url && url->kind == 3 && absolute);
      ++calls;
      if (calls == failAt || url->path.size() >= size) return false;
      memcpy(path, url->path.c_str(), url->path.size() + 1);
      return true;
    }
    static void CFRelease(Object* object) { assert(object); ++released; --live; delete object; }
  CPP
  code += resolver
  code += <<~'CPP'
    static void check(std::string path, int fail, int expected, const std::string& expectedPath, int expectedCalls) {
      failAt = fail; calls = created = released = 0;
      assert(resolveApplicationExecutable(path) == expected);
      assert(path == expectedPath);
      assert(calls == expectedCalls && created == released && live == 0);
    }
    int main(int argc, char** argv) {
      assert(argc == 2);
      std::string root = argv[1], bundle = root + "/Sample é.app";
      selected = bundle + "/Contents/MacOS/Runner";
      check(root + "/plain", 0, noErr, root + "/plain", 0);
      check(root + "/missing", 0, -ENOENT, root + "/missing", 0);
      check(bundle, 0, noErr, selected, 4);
      check(root + "/link.app", 0, noErr, selected, 4);
      for (int fail = 1; fail <= 4; ++fail)
        check(bundle, fail, kLSNoExecutableErr, bundle, fail);
      selected = std::string(PATH_MAX, 'x');
      check(bundle, 0, kLSNoExecutableErr, bundle, 4);
      // Honor the CF-selected layout rather than hard-code Contents/MacOS.
      selected = root + "/Legacy.app/Runner";
      check(bundle, 0, noErr, selected, 4);
    }
  CPP
  File.write("#{dir}/probe.cpp", code)
  system(ENV.fetch('CXX', 'clang++'), '-std=c++11', '-g', '-fsanitize=address,undefined', "#{dir}/probe.cpp", '-o', "#{dir}/probe", exception: true)
  system("#{dir}/probe", dir, exception: true)
end
puts 'PASS: bundle resolver paths, failures, ownership and launch-call ordering'

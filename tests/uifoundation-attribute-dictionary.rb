#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

root = ARGV[0] || File.expand_path('..', __dir__)
test_src = File.join(root, 'tests/uifoundation-attribute-dictionary.m')
abort("Test source not found at #{test_src}") unless File.exist?(test_src)

has_darling = system('darling shell true >/dev/null 2>&1')
guest_bin = '/tmp/uifoundation_attribute_dictionary_test_rb'
src_path = has_darling ? "/Volumes/SystemRoot#{test_src}" : test_src
compile_cmd = ['clang', '-fno-objc-arc', '-framework', 'Foundation', src_path, '-o', guest_bin]
compile_cmd.unshift('darling', 'shell') if has_darling
out, err, status = Open3.capture3(*compile_cmd)
abort("Compilation failed:\n#{err}\n#{out}") unless status.success?

run_cmd = has_darling ? ['darling', 'shell', guest_bin] : [guest_bin]
out, err, status = Open3.capture3(*run_cmd)
puts out
warn err unless err.empty?
abort('FAIL: uifoundation-attribute-dictionary') unless status.success? && out.include?('PASS')
puts 'PASS: uifoundation-attribute-dictionary'

#!/usr/bin/env ruby
# Persist a human concept approval with SHA-256 hashes of every approval input.
require 'digest'
require 'json'
require 'pathname'
require 'time'

unless ARGV.length == 2 && ARGV[1] == '--confirm-human-approval'
  abort('Usage: ruby scripts/record_approval.rb RUN_DIR --confirm-human-approval')
end

root = File.expand_path('..', __dir__)
run_dir = File.expand_path(ARGV[0], root)
unless run_dir.start_with?(File.join(root, 'runs') + File::SEPARATOR)
  abort('RUN_DIR must be inside this workspace runs/ directory')
end

def file_sha256(path)
  Digest::SHA256.file(path).hexdigest
end

def collect_files(path)
  return [path] if File.file?(path)
  return Dir.glob(File.join(path, '**', '*')).select { |entry| File.file?(entry) }.sort if File.directory?(path)
  []
end

inputs = %w[
  docs/prd.md
  docs/design.md
  docs/story-service.md
  docs/story-work.md
].map { |relative| File.join(root, relative) }
inputs.concat(%w[01-reference-analysis.md 01-reference-analysis.yaml].map { |name| File.join(run_dir, name) })
inputs << File.join(run_dir, '02-key-screens')
inputs << File.join(run_dir, '03-concept-decision.md')
inputs << File.join(run_dir, '02-key-screens', 'figma-state.json')
inputs << File.join(run_dir, '02-key-screens', 'figma-capabilities.json')

missing = inputs.reject { |path| File.file?(path) || File.directory?(path) }
abort("Cannot record approval; missing inputs: #{missing.map { |path| Pathname.new(path).relative_path_from(Pathname.new(root)) }.join(', ')}") unless missing.empty?

input_hashes = {}
inputs.each do |input|
  collect_files(input).each do |path|
    relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
    input_hashes[relative] = file_sha256(path)
  end
end

record = {
  'stage' => 3,
  'status' => 'approved',
  'approved_at_utc' => Time.now.utc.iso8601,
  'approval_method' => 'explicit_human_confirmation',
  'input_hashes' => input_hashes,
  'input_set_sha256' => Digest::SHA256.hexdigest(JSON.generate(input_hashes.sort.to_h))
}

approval_path = File.join(run_dir, '03-approval.json')
File.write(approval_path, JSON.pretty_generate(record) + "\n")
puts "Recorded approval snapshot: #{Pathname.new(approval_path).relative_path_from(Pathname.new(root))}"
puts "Hashed #{input_hashes.length} input files"

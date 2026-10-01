#!/usr/bin/env ruby
# Read-only gate evaluator for the Circle harness.
require 'digest'
require 'json'
require 'pathname'
require 'rexml/document'
require 'rexml/xpath'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
abort("Usage: ruby scripts/judge.rb RUN_DIR [--through N]") if ARGV.empty?
RUN_DIR = File.expand_path(ARGV[0], ROOT)
through_index = ARGV.index('--through')
THROUGH = through_index ? Integer(ARGV.fetch(through_index + 1)) : 5
$failures = []
$passes = []

def record(condition, message)
  (condition ? $passes : $failures) << message
end

def load_yaml(path)
  YAML.safe_load(File.read(path))
end

def load_json(path)
  JSON.parse(File.read(path))
end

def file_sha256(path)
  Digest::SHA256.file(path).hexdigest
end

def approval_inputs(run_dir)
  inputs = %w[
    docs/prd.md docs/design.md docs/story-service.md docs/story-work.md
  ].map { |relative| File.join(ROOT, relative) }
  inputs.concat(%w[01-reference-analysis.md 01-reference-analysis.yaml].map { |name| File.join(run_dir, name) })
  inputs << File.join(run_dir, '02-key-screens')
  inputs << File.join(run_dir, '03-concept-decision.md')
  files = []
  inputs.each do |path|
    return nil unless File.exist?(path)
    if File.file?(path)
      files << path
    elsif File.directory?(path)
      files.concat(Dir.glob(File.join(path, '**', '*')).select { |entry| File.file?(entry) }.sort)
    end
  end
  files.sort.each_with_object({}) do |path, hashes|
    relative = Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
    hashes[relative] = file_sha256(path)
  end
end

def check_approval(run_dir)
  path = File.join(run_dir, '03-approval.json')
  unless File.file?(path)
    record(false, 'stage 3 human approval snapshot exists')
    return
  end
  approval = load_json(path)
  record(approval['stage'] == 3 && approval['status'] == 'approved' &&
         approval['approval_method'] == 'explicit_human_confirmation', 'stage 3 human approval is explicit')
  current = approval_inputs(run_dir)
  record(!current.nil?, 'approval inputs still exist')
  return unless current
  record(approval['input_hashes'] == current, 'approval input file hashes are unchanged')
  expected_set = Digest::SHA256.hexdigest(JSON.generate(current.sort.to_h))
  record(approval['input_set_sha256'] == expected_set, 'approval input-set hash matches')
end

begin
  artifacts = load_yaml(File.join(ROOT, 'harness-artifacts.yaml'))
  rules = load_yaml(File.join(ROOT, 'harness-rules.yaml'))
  validation = load_yaml(File.join(ROOT, 'validation-review.yaml'))
  stage_entries = artifacts.fetch('stages').select { |stage| stage.fetch('id') <= THROUGH }

  stage_entries.each do |stage|
    required_artifacts = [stage.fetch('artifact')] + stage.fetch('additional_artifacts', [])
    required_artifacts.each do |artifact|
      path = File.join(RUN_DIR, artifact)
      record(File.exist?(path), "stage #{stage.fetch('id')} artifact exists: #{artifact}")
    end
  end

  if THROUGH >= 1
    reference_path = File.join(RUN_DIR, '01-reference-analysis.yaml')
    if File.file?(reference_path)
      gate = load_yaml(reference_path).fetch('gate')
      record(gate['status'] == 'passed', 'stage 1 reference gate is passed')
      record(gate['selected_points'].is_a?(Array) && !gate['selected_points'].empty?, 'stage 1 has selected reference points')
      record(gate['excluded_points'].is_a?(Array) && !gate['excluded_points'].empty?, 'stage 1 has explicit exclusions')
      record(gate['source_urls'].is_a?(Array) && !gate['source_urls'].empty?, 'stage 1 references are traceable')
    end
  end

  if THROUGH >= 2
    screens_dir = File.join(RUN_DIR, '02-key-screens')
    metrics_path = File.join(screens_dir, 'metrics.yaml')
    capabilities_path = File.join(screens_dir, 'figma-capabilities.json')
    state_path = File.join(screens_dir, 'figma-state.json')
    record(File.file?(metrics_path), 'key-screen metrics.yaml exists')
    record(File.file?(capabilities_path), 'current-session Figma capability evidence exists')
    record(File.file?(state_path), 'Figma MCP state evidence exists')
    if File.file?(metrics_path) && File.file?(state_path) && File.file?(capabilities_path)
      metadata = load_yaml(metrics_path)
      capabilities = load_json(capabilities_path)
      state = load_json(state_path)
      record((2..3).cover?(metadata.fetch('screens').length), 'stage 2 contains 2–3 key screens')
      figma_rules = rules.fetch('figma_gate')
      available_tools = capabilities.fetch('available_tools', [])
      figma_rules.fetch('required_tools').each do |tool|
        found = available_tools.any? { |name| name.to_s.match?(/(?:^|__)figma_?#{Regexp.escape(tool)}\z/) || name.to_s.end_with?("__#{tool}") }
        record(found, "Figma MCP tool is available: #{tool}")
      end
      record(capabilities['run_id'] == File.basename(RUN_DIR), 'Figma capability evidence belongs to this run')
      record(state['verified_via'] == figma_rules.fetch('verified_via_value'), 'Figma state was read through Figma MCP')
      record(state['run_id'] == File.basename(RUN_DIR), 'Figma state belongs to this run')
      record(state['capabilities_sha256'] == Digest::SHA256.file(capabilities_path).hexdigest,
             'Figma state references the current capability evidence')
      record(state['file_url'].to_s.match?(%r{\Ahttps://(?:www\.)?figma\.com/design/}) && !state['file_key'].to_s.empty?, 'Figma Design file URL and key are recorded')
      frames = state.fetch('frames', [])

      metadata.fetch('screens').each do |screen|
        file_path = File.join(screens_dir, screen.fetch('file'))
        record(File.file?(file_path), "screen export exists: #{screen.fetch('file')}")
        next unless File.file?(file_path)

        doc = REXML::Document.new(File.read(file_path))
        svg = doc.root
        width = svg.attributes['width'].to_i
        height = svg.attributes['height'].to_i
        expected_width = validation.dig('validation', 'key_screen_dimensions', 'width')
        expected_height = validation.dig('validation', 'key_screen_dimensions', 'height')
        record(width == expected_width && height == expected_height, "screen dimensions are #{expected_width}x#{expected_height}: #{screen.fetch('file')}")
        record(screen.fetch('width') == width && screen.fetch('height') == height, "metrics dimensions match export: #{screen.fetch('file')}")

        actual_text = REXML::XPath.match(doc, '//text').map { |node| node.texts.map(&:value).join }
        actual_max = actual_text.map(&:length).max || 0
        record(screen.fetch('text_characters_per_string') == actual_max, "declared text count matches visible SVG text: #{screen.fetch('file')}")
        rules.fetch('copy_keyword_scan').fetch('forbidden_phrases').each do |phrase|
          visible_text = actual_text.join(' ').downcase
          record(!visible_text.include?(phrase.downcase), "visible SVG copy excludes unsupported phrase '#{phrase}': #{screen.fetch('file')}")
        end
        rules.fetch('checks').reject { |check| check.fetch('id') == 'location-privacy' }.each do |check|
          value = screen[check.fetch('field')]
          threshold = check.fetch('value')
          passed = case check.fetch('operator')
                   when 'equals' then value == threshold
                   when 'less_than_or_equal' then value.is_a?(Numeric) && value <= threshold
                   else false
                   end
          record(passed, "#{check.fetch('id')} for #{screen.fetch('file')}")
        end

        frame = frames.find { |candidate| candidate['name'] == screen['figma_frame_name'] }
        record(!frame.nil?, "Figma node exists for #{screen.fetch('file')}")
        if frame
          record(!frame['node_id'].to_s.empty?, "Figma node id recorded for #{screen.fetch('file')}")
          record(frame['width'] == width && frame['height'] == height, "Figma node dimensions match exported file: #{screen.fetch('file')}")
          record(frame['visible_text'] == actual_text, "Figma visible text matches exported file: #{screen.fetch('file')}")
        end
      end

      privacy_check = rules.fetch('checks').find { |check| check.fetch('id') == 'location-privacy' }
      privacy_check.fetch('required_fields').each do |field, spec|
        %w[find_mode return_check].each do |behavior|
          value = metadata.dig('behaviors', behavior, field)
          record(value == spec.fetch('value'), "location-privacy #{behavior}.#{field}")
        end
      end
    end
  end

  check_approval(RUN_DIR) if THROUGH >= 3

  if THROUGH >= 4
    copy_path = File.join(RUN_DIR, '04-ux-copy.yaml')
    if File.file?(copy_path)
      copy = load_yaml(copy_path)
      keyword_rules = rules.fetch('copy_keyword_scan')
      copy.fetch('screens').each do |screen|
        record(screen['primary_information_count'] == 1, "one primary information item: #{screen['screen']}")
        record(screen.fetch('list_items', []).empty?, "no text list on circular screen: #{screen['screen']}")
        visible_copy = [screen.fetch('primary_text', '')] + screen.fetch('supporting_text', [])
        visible_copy.each do |text|
          record(text.length <= 20, "visible copy <= 20 characters: #{screen['screen']}")
          keyword_rules.fetch('forbidden_phrases').each do |phrase|
            record(!text.downcase.include?(phrase.downcase), "visible copy excludes unsupported phrase '#{phrase}': #{screen['screen']}")
          end
        end
      end
    end
  end

  if THROUGH >= 5
    review_path = File.join(RUN_DIR, '05-final-design', 'review.yaml')
    if File.file?(review_path)
      review = load_yaml(review_path)
      %w[design_tokens components screen_design].each do |field|
        output = review[field]
        output_path = output && File.join(RUN_DIR, output)
        record(output_path && File.file?(output_path), "final output exists: #{field}")
      end
      record(review['unselected_explorations'].is_a?(Array) && !review['unselected_explorations'].empty?, 'unselected explorations are documented')
      reasons = review['unselected_explorations'] || []
      record(reasons.all? { |item| !item['reason'].to_s.strip.empty? }, 'each unselected exploration has a reason')
      record(!review['final_selection_reason'].to_s.strip.empty?, 'final selection reason is documented')
    end
  end
rescue StandardError => e
  $failures << "judge error: #{e.class}: #{e.message}"
end

$passes.each { |message| puts "PASS #{message}" }
$failures.each { |message| puts "FAIL #{message}" }
puts "Result: #{$passes.length} passed, #{$failures.length} failed"
exit($failures.empty? ? 0 : 1)

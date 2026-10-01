#!/usr/bin/env ruby
# Reproducible integration tests for every configured harness gate.
require 'fileutils'
require 'digest'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'yaml'

ROOT = File.expand_path('..', __dir__)

class HarnessGateTest < Minitest::Test
  def setup
    @run_dir = Dir.mktmpdir('circle-harness-test-', File.join(ROOT, 'runs'))
    build_fixture
  end

  def teardown
    FileUtils.remove_entry(@run_dir) if @run_dir && File.directory?(@run_dir)
  end

  def build_fixture
    write('01-reference-analysis.md', '# Research')
    write_yaml('01-reference-analysis.yaml', {
      'gate' => {
        'status' => 'passed',
        'selected_points' => ['Ring guidance'],
        'excluded_points' => ['SOS feature'],
        'source_urls' => ['https://example.com/source']
      }
    })
    screens = [
      ['01-party-home.svg', '01 Party Home', 'Party'],
      ['02-find-mode.svg', '02 Find Mode', 'Find'],
      ['03-your-turn.svg', '03 Your Turn', 'Vote']
    ]
    screen_data = screens.map do |filename, frame_name, visible_text|
      write("02-key-screens/#{filename}", %(<svg xmlns="http://www.w3.org/2000/svg" width="440" height="440"><text>#{visible_text}</text></svg>))
      { 'file' => filename, 'figma_frame_name' => frame_name, 'width' => 440, 'height' => 440,
        'primary_information_count' => 1, 'text_characters_per_string' => visible_text.length,
        'list_item_count' => 0, 'gesture_step_count' => 1, 'completion_time_seconds' => 2 }
    end
    screen_data[1].merge!('location_audience' => 'party_members_only', 'user_opt_in' => true,
                          'auto_disable_on_party_end' => true)
    write_yaml('02-key-screens/metrics.yaml', {
      'screens' => screen_data,
      'behaviors' => {
        'find_mode' => { 'location_audience' => 'party_members_only', 'user_opt_in' => true, 'auto_disable_on_party_end' => true },
        'return_check' => { 'location_audience' => 'party_members_only', 'user_opt_in' => true, 'auto_disable_on_party_end' => true }
      }
    })
    tools = %w[
      mcp__codex_apps__figma_create_new_file
      mcp__codex_apps__figma_use_figma
      mcp__codex_apps__figma_get_metadata
      mcp__codex_apps__figma_get_screenshot
    ]
    write_json('02-key-screens/figma-capabilities.json', {
      'run_id' => File.basename(@run_dir), 'available_tools' => tools
    })
    capabilities_hash = Digest::SHA256.file(File.join(@run_dir, '02-key-screens/figma-capabilities.json')).hexdigest
    write_json('02-key-screens/figma-state.json', {
      'verified_via' => 'figma_mcp', 'run_id' => File.basename(@run_dir),
      'capabilities_sha256' => capabilities_hash,
      'file_url' => 'https://www.figma.com/design/mock123/Circle',
      'file_key' => 'mock123',
      'frames' => screens.map do |_filename, frame_name, visible_text|
        { 'name' => frame_name, 'node_id' => "node-#{frame_name.downcase.tr(' ', '-')}",
          'width' => 440, 'height' => 440, 'visible_text' => [visible_text] }
      end
    })
    write('03-concept-decision.md', '# Ring Pulse')
    write('04-screen-spec-and-explorations.md', '# Screen spec')
    write('04-ux-copy.md', '# Copy\n\nRationale: SOS를 지원하지 않는다.')
    write_yaml('04-ux-copy.yaml', {
      'screens' => [{ 'screen' => 'party-home', 'primary_information_count' => 1,
                     'primary_text' => 'Party', 'supporting_text' => ['Now playing'],
                     'list_items' => [], 'rationale' => 'SOS를 지원하지 않는다.' }]
    })
    write('05-final-design/tokens.json', '{}')
    write('05-final-design/components.json', '{}')
    write('05-final-design/screen.svg', '<svg/>')
    write_yaml('05-final-design/review.yaml', {
      'design_tokens' => '05-final-design/tokens.json',
      'components' => '05-final-design/components.json',
      'screen_design' => '05-final-design/screen.svg',
      'unselected_explorations' => [{ 'name' => 'Pulse field', 'reason' => 'Reduced visual hierarchy.' }],
      'final_selection_reason' => 'Ring states make the key action clear.'
    })
  end

  def test_valid_fixture_passes_all_five_stages
    record_approval
    output, status = judge(5)
    assert status.success?, output
    assert_includes output, 'Figma visible text matches exported file'
    assert_includes output, 'approval input file hashes are unchanged'
    assert_includes output, "visible copy excludes unsupported phrase 'SOS'"
    assert_includes output, 'final selection reason is documented'
  end

  def test_resume_is_rejected_when_an_approved_input_changes
    record_approval
    write('03-concept-decision.md', '# Changed after approval')
    output, status = judge(3)
    refute status.success?
    assert_includes output, 'approval input file hashes are unchanged'
  end

  def test_stage_three_cannot_pass_without_human_approval
    output, status = judge(3)
    refute status.success?
    assert_includes output, 'stage 3 human approval snapshot exists'
  end

  def test_stage_two_rejects_state_without_figma_mcp_evidence
    state_path = File.join(@run_dir, '02-key-screens/figma-state.json')
    state = JSON.parse(File.read(state_path))
    state['verified_via'] = 'manual-export'
    File.write(state_path, JSON.generate(state))
    output, status = judge(2)
    refute status.success?
    assert_includes output, 'Figma state was read through Figma MCP'
  end

  def test_stage_two_rejects_missing_write_capability
    path = File.join(@run_dir, '02-key-screens/figma-capabilities.json')
    capabilities = JSON.parse(File.read(path))
    capabilities['available_tools'].delete('mcp__codex_apps__figma_use_figma')
    File.write(path, JSON.generate(capabilities))
    output, status = judge(2)
    refute status.success?
    assert_includes output, 'Figma MCP tool is available: use_figma'
    assert_includes output, 'Figma state references the current capability evidence'
  end

  def test_stage_two_rejects_figma_state_that_differs_from_export
    state_path = File.join(@run_dir, '02-key-screens/figma-state.json')
    state = JSON.parse(File.read(state_path))
    state['frames'][0]['visible_text'] = ['Different text']
    File.write(state_path, JSON.generate(state))
    output, status = judge(2)
    refute status.success?
    assert_includes output, 'Figma visible text matches exported file'
  end

  def test_keyword_scan_checks_visible_svg_text_but_not_rule_prose
    path = File.join(@run_dir, '02-key-screens/01-party-home.svg')
    File.write(path, '<svg xmlns="http://www.w3.org/2000/svg" width="440" height="440"><text>SOS</text></svg>')
    metrics_path = File.join(@run_dir, '02-key-screens/metrics.yaml')
    metrics = YAML.safe_load(File.read(metrics_path))
    metrics['screens'][0]['text_characters_per_string'] = 3
    File.write(metrics_path, metrics.to_yaml)
    state_path = File.join(@run_dir, '02-key-screens/figma-state.json')
    state = JSON.parse(File.read(state_path))
    state['frames'][0]['visible_text'] = ['SOS']
    File.write(state_path, JSON.generate(state))
    output, status = judge(2)
    refute status.success?
    assert_includes output, "visible SVG copy excludes unsupported phrase 'SOS'"
  end

  def test_every_numeric_and_privacy_rule_rejects_a_violation
    cases = [
      ['primary_information_count', 2, 'one-primary-information'],
      ['text_characters_per_string', 21, 'circular-screen-text-limit'],
      ['list_item_count', 1, 'no-list-on-circular-screen'],
      ['gesture_step_count', 2, 'core-gesture-step-limit'],
      ['completion_time_seconds', 4, 'core-interaction-time-limit'],
      ['location_audience', 'public', 'location-privacy find_mode.location_audience'],
      ['user_opt_in', false, 'location-privacy find_mode.user_opt_in'],
      ['auto_disable_on_party_end', false, 'location-privacy find_mode.auto_disable_on_party_end']
    ]
    cases.each do |field, invalid_value, expected_message|
      build_fixture
      metrics_path = File.join(@run_dir, '02-key-screens/metrics.yaml')
      metrics = YAML.safe_load(File.read(metrics_path))
      if %w[location_audience user_opt_in auto_disable_on_party_end].include?(field)
        metrics['behaviors']['find_mode'][field] = invalid_value
      else
        metrics['screens'][0][field] = invalid_value
      end
      File.write(metrics_path, metrics.to_yaml)
      output, status = judge(2)
      refute status.success?, "Expected #{field} violation to fail"
      assert_includes output, expected_message
    end
  end

  def test_stage_one_reference_gate_must_be_passed_and_traceable
    path = File.join(@run_dir, '01-reference-analysis.yaml')
    gate = YAML.safe_load(File.read(path))
    gate['gate']['status'] = 'pending'
    gate['gate']['source_urls'] = []
    File.write(path, gate.to_yaml)
    output, status = judge(1)
    refute status.success?
    assert_includes output, 'stage 1 reference gate is passed'
    assert_includes output, 'stage 1 references are traceable'
  end

  def test_stage_five_requires_final_files_and_selection_reasons
    review_path = File.join(@run_dir, '05-final-design/review.yaml')
    review = YAML.safe_load(File.read(review_path))
    review['components'] = '05-final-design/missing-components.json'
    review['final_selection_reason'] = ''
    File.write(review_path, review.to_yaml)
    output, status = judge(5)
    refute status.success?
    assert_includes output, 'final output exists: components'
    assert_includes output, 'final selection reason is documented'
  end

  def test_context_paths_resolve_under_docs_after_move
    config = YAML.safe_load(File.read(File.join(ROOT, 'orchestrator-rules.yaml')))
    expected = %w[docs/prd.md docs/design.md docs/story-service.md docs/story-work.md]
    assert_equal expected, config.dig('preflight', 'required_context')
    expected.each { |relative| assert File.file?(File.join(ROOT, relative)), "Missing #{relative}" }
    %w[prd.md design.md story-service.md story-work.md].each do |basename|
      refute File.exist?(File.join(ROOT, basename)), "Stale root-level file #{basename} exists"
      refute_includes File.read(File.join(ROOT, 'CLAUDE.md')), "- `#{basename}`"
    end
  end

  def test_keyword_scan_ignores_rationale_but_checks_visible_copy
    record_approval
    output, status = judge(5)
    assert status.success?, output
    copy_path = File.join(@run_dir, '04-ux-copy.yaml')
    copy = YAML.safe_load(File.read(copy_path))
    copy['screens'][0]['primary_text'] = 'SOS'
    File.write(copy_path, copy.to_yaml)
    output, status = judge(4)
    refute status.success?
    assert_includes output, "visible copy excludes unsupported phrase 'SOS'"
  end

  def test_text_length_limit_is_enforced_on_ux_copy
    record_approval
    copy_path = File.join(@run_dir, '04-ux-copy.yaml')
    copy = YAML.safe_load(File.read(copy_path))
    copy['screens'][0]['primary_text'] = 'A' * 21
    File.write(copy_path, copy.to_yaml)
    output, status = judge(4)
    refute status.success?
    assert_includes output, 'visible copy <= 20 characters'
  end

  def test_identical_gate_inputs_produce_identical_judgments
    record_approval
    metrics_path = File.join(@run_dir, '02-key-screens/metrics.yaml')
    metrics = YAML.safe_load(File.read(metrics_path))
    metrics['behaviors']['find_mode']['location_audience'] = 'public'
    File.write(metrics_path, metrics.to_yaml)
    first_output, first_status = judge(2)
    second_output, second_status = judge(2)
    assert_equal first_status.exitstatus, second_status.exitstatus
    assert_equal first_output, second_output
    refute first_status.success?
    assert_includes first_output, 'location-privacy find_mode.location_audience'
  end

  private

  def write(relative, content)
    path = File.join(@run_dir, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def write_yaml(relative, data)
    write(relative, data.to_yaml)
  end

  def write_json(relative, data)
    write(relative, JSON.pretty_generate(data))
  end

  def record_approval
    command = ['ruby', File.join(ROOT, 'scripts/record_approval.rb'), @run_dir, '--confirm-human-approval']
    output, status = Open3.capture2e(*command)
    assert status.success?, output
  end

  def judge(through)
    Open3.capture2e('ruby', File.join(ROOT, 'scripts/judge.rb'), @run_dir, '--through', through.to_s)
  end
end

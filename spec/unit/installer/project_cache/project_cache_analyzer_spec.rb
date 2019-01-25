require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    module ProjectCache
      describe ProjectCacheAnalyzer do
        before do
          @sandbox = config.sandbox
          @project_object_version = '1'
          @build_configurations = { 'Debug' => :debug }
          @banana_lib = fixture_pod_target('banana-lib/BananaLib.podspec')
          @orange_lib = fixture_pod_target('orange-framework/OrangeFramework.podspec')
          @monkey_lib = fixture_pod_target('monkey/monkey.podspec')
          @pod_targets = [@banana_lib, @orange_lib, @monkey_lib]
          @main_aggregate_target = fixture_aggregate_target(@pod_targets)
          @secondary_aggregate_target = fixture_aggregate_target([@banana_lib, @monkey_lib])
        end

        describe 'in general' do
          it 'returns all pod targets if there is no cache' do
            empty_cache = ProjectInstallationCache.new
            analyzer = ProjectCacheAnalyzer.new(@sandbox, empty_cache, @build_configurations, @project_object_version, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns an empty result if no targets have changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns the list of pod targets that have changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            @banana_lib.root_spec.stubs(:checksum).returns('Blah')
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([@banana_lib])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns all pod targets and aggregate targets if the build configurations have changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations.merge('Production' => :release), @project_object_version, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns all pod targets and aggregate targets if the project object version configurations has changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, '2', @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns all aggregate targets if one has changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = {
              @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@main_aggregate_target),
              @secondary_aggregate_target.label => TargetCacheKey.from_cache_hash('BUILD_SETTINGS_CHECKSUM' => 'Blah'),
            }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, @pod_targets, [@main_aggregate_target, @secondary_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target, @secondary_aggregate_target])
          end

          it 'returns all aggregate targets if one has been removed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = {
              @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@main_aggregate_target),
            }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, [], [@main_aggregate_target, @secondary_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target, @secondary_aggregate_target])
          end

          it 'returns all aggregate targets if one has been added' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(pod_target)] }]
            cache_key_by_aggregate_target_labels = {}
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, [], [@main_aggregate_target, @secondary_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target, @secondary_aggregate_target])
          end

          it 'returns an empty list of aggregate targets when podfile has no targets and empty cache' do
            cache = ProjectInstallationCache.new
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, [], [])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([])
          end
        end
      end
    end
  end
end

module Pod
  class Installer
    class TargetCacheKey
      require 'fileutils'
      require 'cocoapods/target/pod_target.rb'
      require 'cocoapods/target/aggregate_target.rb'

      attr_reader :type
      attr_reader :hash

      def initialize(type, hash)
        @type = type
        @hash = hash
      end

      def key_difference(other)
        if other.type != type
          :project
        else
          case type
          when :pod_target
            return :project if other.hash.keys.size - hash.keys.size != 0
            return :project if other.hash['CHECKSUM'] != hash['CHECKSUM']
            return :project if other.hash['SPECS'].size - hash['SPECS'].size != 0
            return :project if hash['FILES'] && other.hash['FILES'] != hash['FILES']
          end

          return :project if (other.hash['XCCONFIG_FILEPATHS'].keys - hash['XCCONFIG_FILEPATHS'].keys).size > 0

          this_build_settings = hash['BUILD_SETTINGS']
          other_build_settings = other.hash['BUILD_SETTINGS']
          this_build_settings.each do |key, settings_string|
            return :project if other_build_settings[key].nil?
            this_settings_string = StringIO.new(settings_string)
            other_settings_string = StringIO.new(other_build_settings[key])
            identical = FileUtils.compare_stream(this_settings_string, other_settings_string)
            return :project if !identical
          end

          :none
        end
      end

      def to_cache_hash
        hash.reject { |k,_| k == 'BUILD_SETTINGS' }
      end

      def self.from_cache_hash(hash)
        build_settings = {}
        hash['XCCONFIG_FILEPATHS'].each do |key, path|
          build_settings[key] = Xcodeproj::Config.new(Pathname(path)).to_s if File.exist?(path)
        end
        hash['BUILD_SETTINGS'] = build_settings
        if files = hash['FILES']
          hash['FILES'] = files.sort
        end
        type = hash['CHECKSUM'] ? :pod_target : :aggregate
        TargetCacheKey.new(type, hash)
      end

      def self.from_pod_target(pod_target, is_local_pod: false, checkout_options: nil)
        xcconfig_paths = {}
        xcconfig_paths["#{pod_target.label}"] = pod_target.xcconfig_path_for_spec.to_s
        (pod_target.app_specs + pod_target.test_specs).each do |spec|
          xcconfig_paths["#{spec.name}"] = pod_target.xcconfig_path_for_spec(spec).to_s
        end

        build_settings = {}
        build_settings["#{pod_target.label}"] = pod_target.build_settings.xcconfig.to_s
        pod_target.test_spec_build_settings.each do |name, settings|
          build_settings[name] = settings.xcconfig.to_s
        end
        pod_target.app_spec_build_settings.each do |name, settings|
          build_settings[name] = settings.xcconfig.to_s
        end

        contents = {
            'CHECKSUM' => pod_target.root_spec.checksum,
            'SPECS' => pod_target.specs.map { |spec| spec.to_s },
            'BUILD_SETTINGS' => build_settings,
            'XCCONFIG_FILEPATHS' => xcconfig_paths
        }
        contents['FILES'] = pod_target.all_files.sort if is_local_pod
        contents['CHECKOUT_OPTIONS'] = checkout_options if checkout_options
        TargetCacheKey.new(:pod_target, contents)
      end

      def self.from_aggregate_target(aggregate_target)
        build_settings = {}
        xcconfig_paths = {}
        aggregate_target.user_build_configurations.keys.each do |configuration|
          build_settings[configuration] = aggregate_target.build_settings(configuration).xcconfig.to_s
          xcconfig_paths[configuration] = aggregate_target.xcconfig_path_for_build_configuration(configuration).to_s
        end

        TargetCacheKey.new(:aggregate, {
            'BUILD_SETTINGS' => build_settings,
            'XCCONFIG_FILEPATHS' => xcconfig_paths
        })
      end
    end
  end
end

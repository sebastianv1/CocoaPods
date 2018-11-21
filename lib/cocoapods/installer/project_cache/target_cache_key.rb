module Pod
  class Installer
    class TargetCacheKey
      require 'cocoapods/target/pod_target.rb'
      require 'cocoapods/target/aggregate_target.rb'
      require 'digest'

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

          this_build_settings = hash['BUILD_SETTINGS']
          other_build_settings = other.hash['BUILD_SETTINGS']
          this_build_settings.each do |key, settings_checksum|
            return :project if other_build_settings[key].nil?
            return :project if settings_checksum != other_build_settings[key]
          end

          :none
        end
      end

      def to_cache_hash
        hash
      end

      def self.from_cache_hash(hash)
        if files = hash['FILES']
          hash['FILES'] = files.sort
        end
        type = hash['CHECKSUM'] ? :pod_target : :aggregate
        TargetCacheKey.new(type, hash)
      end

      def self.from_pod_target(pod_target, is_local_pod: false, checkout_options: nil)
        build_settings = {}
        build_settings["#{pod_target.label}"] = Digest::MD5.hexdigest(pod_target.build_settings.xcconfig.to_s)
        pod_target.test_spec_build_settings.each do |name, settings|
          build_settings[name] = Digest::MD5.hexdigest(settings.xcconfig.to_s)
        end
        pod_target.app_spec_build_settings.each do |name, settings|
          build_settings[name] = Digest::MD5.hexdigest(settings.xcconfig.to_s)
        end

        contents = {
            'CHECKSUM' => pod_target.root_spec.checksum,
            'SPECS' => pod_target.specs.map { |spec| spec.to_s },
            'BUILD_SETTINGS' => build_settings
        }
        contents['FILES'] = pod_target.all_files.sort if is_local_pod
        contents['CHECKOUT_OPTIONS'] = checkout_options if checkout_options
        TargetCacheKey.new(:pod_target, contents)
      end

      def self.from_aggregate_target(aggregate_target)
        build_settings = {}
        aggregate_target.user_build_configurations.keys.each do |configuration|
          build_settings[configuration] = Digest::MD5.hexdigest(aggregate_target.build_settings(configuration).xcconfig.to_s)
        end

        TargetCacheKey.new(:aggregate, {
            'BUILD_SETTINGS' => build_settings
        })
      end
    end
  end
end

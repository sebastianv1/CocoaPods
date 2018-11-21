module Pod
  class Installer
    class TargetMetadata
      attr_reader :target_label
      attr_reader :native_target_uuid
      attr_reader :container_project_path

      def initialize(target_label, native_target_uuid, container_project_path)
        @target_label = target_label
        @native_target_uuid = native_target_uuid
        @container_project_path = container_project_path
      end

      def to_hash
        {
            'LABEL' => target_label,
            'UUID' => native_target_uuid,
            'PROJECT_PATH' => container_project_path
        }
      end

      def to_s
        "#{target_label} : #{native_target_uuid} : #{container_project_path}"
      end

      def self.cache_metadata_from_hash(hash)
        TargetMetadata.new(hash['LABEL'], hash['UUID'], hash['PROJECT_PATH'])
      end

      def self.cache_metadata_from_native_target(native_target)
        TargetMetadata.new(native_target.name, native_target.uuid, native_target.project.path.to_s)
      end
    end
  end
end

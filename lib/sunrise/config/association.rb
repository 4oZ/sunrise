require 'sunrise/config/base'

module Sunrise
  module Config
    class Association < Base
    
      def resource_name
        @resource_name ||= (@config_options[:class_name] || name)
      end
    
      def model
        @model ||= Utils.lookup(resource_name.to_s.camelize)
      end
    
      # Compare relation by model_type
      def is_this?(model_type)
        name.to_s.downcase == model_type.to_s.downcase
      end
    end
  end
end
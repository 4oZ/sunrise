# encoding: utf-8
module Sunrise
  module Models
    class RoleType
      include EnumField::DefineEnum
      
      attr_reader :code
      
      def initialize(code)
        @code = code.to_sym
      end
      
      def title
        I18n.t(@code, :scope => [:manage, :role, :kind])
      end
      
      def self.legal?(value)
        all.map(&:id).include?(value)
      end  
    end
  end
end

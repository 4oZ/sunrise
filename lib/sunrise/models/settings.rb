require "dalli"
require "active_support/cache/dalli_store"

module Sunrise
  module Models
    module Settings
      extend ActiveSupport::Concern
      
      class SettingNotFound < RuntimeError; end
      
      included do 
        cattr_accessor :defaults
        self.defaults = {}.with_indifferent_access

        # cache must follow the contract of ActiveSupport::Cache. Defaults to no-op.
        cattr_accessor :cache
        self.cache = ::ActiveSupport::Cache::DalliStore.new

        # options passed to cache.fetch() and cache.write(). example: {:expires_in => 5.minutes}
        cattr_accessor :cache_options
        self.cache_options = {:expires_in => 1.day}
      end
      
      module ClassMethods
        def cache_key(var_name)
          [target_id, target_type, var_name].compact.map(&:to_s).join("::")
        end
        
        #get or set a variable with the variable as the called method
        def method_missing(method, *args)
          if self.respond_to?(method)
            super
          else
            method_name = method.to_s
          
            #set a value for a variable
            if method_name =~ /=$/
              var_name = method_name.gsub('=', '')
              value = args.first
              self[var_name] = value
          
            #retrieve a value
            else
              self[method_name]
            end
          end
        end
        
        #destroy the specified settings record
        def destroy(var_name)
          var_name = var_name.to_s
          begin
            target(var_name).destroy
            cache.delete(cache_key(var_name))
            true
          rescue NoMethodError
            raise SettingNotFound, "Setting variable \"#{var_name}\" not found"
          end
        end

        def delete_all(conditions = nil)
          cache.clear
          super
        end

        #retrieve all settings as a hash (optionally starting with a given namespace)
        def all(starting_with=nil)
          query = target_scoped
          query = query.where(["var LIKE ?", "#{starting_with}%"]) if starting_with

          result = defaults.dup
          
          query.all.each do |record|
            result[record.var.to_sym] = record.value
          end
          
          result.with_indifferent_access
        end
        
        #get a setting value by [] notation
        def [](var_name)
          cache.fetch(cache_key(var_name), cache_options) do
            if (var = target(var_name)).present?
              var.value
            else
              defaults[var_name.to_sym]
            end
          end
        end
        
        #set a setting value by [] notation
        def []=(var_name, value)
          record = target_scoped.where(:var => var_name.to_s).first
          record ||= new(:var => var_name.to_s)

          record.value = value
          record.save!
          cache.write(cache_key(var_name), value, cache_options)
          value
        end
        
        def merge!(var_name, hash_value)
          raise ArgumentError unless hash_value.is_a?(Hash)
          
          old_value = self[var_name] || {}
          raise TypeError, "Existing value is not a hash, can't merge!" unless old_value.is_a?(Hash)
          
          new_value = old_value.merge(hash_value)
          self[var_name] = new_value if new_value != old_value
          
          new_value
        end

        def target(var_name)
          target_scoped.where(:var => var_name.to_s).first
        end
        
        def target_scoped
          scoped.where(:target_id => target_id, :target_type => target_type)
        end
        
        def target_id
          nil
        end

        def target_type
          nil
        end
        
        def update_attributes(attrs)
          attrs.each do |key, value|
            self[key] = value
          end

          cache.clear
        end

        def to_key
          ['settings']
        end
      end
    end
  end
end
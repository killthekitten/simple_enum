require 'simple_enum/translation'
require 'simple_enum/enum'
require 'simple_enum/accessors'

module SimpleEnum

  # SimpleEnum::Attribute is the base class to be included in objects to get
  # the #as_enum functionality. All the including class needs to provide is
  # a setter and getter for `source`, by default the `source` is `<enum>_cd`.
  # This is similar to how relations work in Rails, the idea is not taint the
  # original method.
  #
  module Attribute
    extend ActiveSupport::Concern

    included do
      extend SimpleEnum::Translation
    end

    module ClassMethods
      def as_enum(name, values, options = {})
        options = SimpleEnum.default_options.merge(options)
        options.assert_valid_keys(:source, :prefix, :with, :whiny)

        enum     = SimpleEnum::Enum.enum(name, values, options)
        accessor = SimpleEnum::Accessors.accessor(enum, options)

        generate_enum_class_methods_for(enum, accessor)
        generate_enum_attribute_methods_for(enum, accessor)

        options[:with].each do |feature|
          send "generate_enum_#{feature}_methods_for", enum, accessor
        end
      end

      private

      def simple_enum_module
        @simple_enum_module ||= begin
          mod = Module.new
          include mod
          mod
        end
      end

      def generate_enum_class_methods_for(enum, accessor)
        singleton_class.send(:define_method, enum.name.pluralize) { enum }
        singleton_class.send(:define_method, "#{enum.name.pluralize}_accessor") { accessor }
      end

      def generate_enum_attribute_methods_for(enum, accessor)
        simple_enum_module.module_eval do
          define_method("#{enum}")  { accessor.read(self) }
          define_method("#{enum}=") { |value| accessor.write(self, value) }
          define_method("#{enum}?") { |value = nil| accessor.selected?(self, value) }
        end
      end

      def generate_enum_dirty_methods_for(enum, accessor)
        simple_enum_module.module_eval do
          define_method("#{enum}_changed?") { accessor.changed?(self) }
          define_method("#{enum}_was")      { accessor.was(self) }
        end
      end

      def generate_enum_query_methods_for(enum, accessor)
        simple_enum_module.module_eval do
          enum.hash.each do |key, value|
            define_method("#{enum.prefix}#{key}?") { accessor.selected?(self, key) }
          end
        end
      end

      def generate_enum_bang_methods_for(enum, accessor)
        simple_enum_module.module_eval do
          enum.hash.each do |key, value|
            define_method("#{enum.prefix}#{key}!") { accessor.write(self, key) }
          end
        end
      end

      def generate_enum_scope_methods_for(enum, accessor)
        return unless respond_to?(:scope)

        enum.hash.each do |key, value|
          scope "#{enum.prefix}#{key}", -> { where(enum.source => value) }
        end
      end
    end
  end
end

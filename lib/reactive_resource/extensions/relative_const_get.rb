module Extensions
  module RelativeConstGet

    # Finds the constant with name +name+, relative to the calling
    # module. For instance, <tt>A::B.const_get_relative("C")</tt> will
    # search for A::C, then ::C. This is heavily inspired by
    # +find_resource_in_modules+ in active_resource.
    def relative_const_get(name)
      module_names = self.name.split("::")
      if module_names.length > 1
        receiver = Object
        namespaces = module_names[0, module_names.size-1].map do |module_name|
          receiver = receiver.const_get(module_name)
        end
        const_args = RUBY_VERSION < "1.9" ? [name] : [name, false]
        if namespace = namespaces.reverse.detect { |ns| ns.const_defined?(*const_args) }
          return namespace.const_get(*const_args)
        else
          raise NameError
        end
      else
        const_get(name)
      end
    end
  end
end

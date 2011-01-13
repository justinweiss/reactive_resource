module ReactiveResource
  module Association
    class HasOneAssociation

      attr_reader :klass, :attribute, :options
      
      def associated_class
        options[:class_name] || klass.relative_const_get(attribute.to_s.capitalize)
      end

      def resolve_relationship(object)
        id_attribute = "#{klass.name.split("::").last.downcase}_id"
        associated_class.find(:one, :params => object.prefix_options.merge(id_attribute => object.id))
      end
      
      # Adds methods for has_one associations, to make dealing with
      # these objects a bit more straightforward. If the attribute name
      # is +headshot+, it will add:
      #
      # * headshot: returns the associated headshot
      def add_helper_methods(klass, attribute)
        association = self
        klass.class_eval do 
          # lawyer.headshot
          define_method(attribute) do
            unless instance_variable_get("@#{attribute}")
              object = association.resolve_relationship(self)
              instance_variable_set("@#{attribute}", object)
            end
            instance_variable_get("@#{attribute}")
          end
        end
      end

      def initialize(klass, attribute, options)
        @klass = klass
        @attribute = attribute
        @options = options

        add_helper_methods(klass, attribute)
      end
    end
  end
end

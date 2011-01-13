module ReactiveResource
  module Association
    class HasManyAssociation

      attr_reader :klass, :attribute, :options
      
      def associated_class
        options[:class_name] || klass.relative_const_get(attribute.to_s.singularize.capitalize)
      end

      def resolve_relationship(object)
        id_attribute = "#{klass.name.split("::").last.downcase}_id"
        associated_class.find(:all, :params => object.prefix_options.merge(id_attribute => object.id))
      end
      
      # Adds methods for belongs_to associations, to make dealing with
      # these objects a bit more straightforward. If the attribute name
      # is +lawyers+, it will add:
      #
      # * lawyers: returns the associated lawyers
      def add_helper_methods(klass, attribute)
        association = self
        klass.class_eval do 
          # lawyer.addresses
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

module ReactiveResource
  module Association
    # Represents and resolves a has_one association
    class HasOneAssociation

      # The class this association is attached to
      attr_reader :klass

      # The attribute name this association represents
      attr_reader :attribute

      # additional options passed in when the association was created
      attr_reader :options

      # Returns the class name of the target of the association. Based
      # off of +attribute+ unless +class_name+ was passed in the
      # +options+ hash.
      def associated_class
        if options[:class_name]
          options[:class_name].constantize
        else
          klass.relative_const_get(attribute.to_s.camelize)
        end
      end

      # Called when this assocation is referenced. Finds and returns
      # the target of this association.
      def resolve_relationship(object)
        id_attribute = "#{klass.name.split("::").last.underscore}_id"
        associated_class.find(:one, :params => object.prefix_options.merge(id_attribute => object.id))
      end
      
      # Adds methods for has_one associations, to make dealing with
      # these objects a bit more straightforward. If the attribute name
      # is +headshot+, it will add:
      #
      # [headshot] returns the associated headshot
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
      
      # Create a new has_one association.
      def initialize(klass, attribute, options)
        @klass = klass
        @attribute = attribute
        @options = options

        add_helper_methods(klass, attribute)
      end
    end
  end
end

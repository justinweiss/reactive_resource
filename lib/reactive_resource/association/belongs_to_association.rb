module ReactiveResource
  module Association
    class BelongsToAssociation

      attr_reader :klass, :attribute, :options
      
      def associated_class
        options[:class_name] || klass.relative_const_get(attribute.to_s.capitalize)
      end

      # A flattened list of attributes from the entire association
      # +belongs_to+ hierarchy, including this association's attribute.
      def associated_attributes
        attributes = [attribute]
        if associated_class
          attributes += associated_class.belongs_to.map(&:attribute)
        end
        attributes.uniq
      end

      def resolve_relationship(object)
        parent_params = object.prefix_options.dup
        parent_params.delete("#{attribute}_id".intern)
        associated_class.find(object.send("#{attribute}_id"), :params => parent_params)
      end
      
      # Adds methods for belongs_to associations, to make dealing with
      # these objects a bit more straightforward. If the attribute name
      # is +lawyer+, it will add:
      #
      # * lawyer: returns the actual lawyer object (after doing a web request)
      # * lawyer_id: returns the lawyer id
      # * lawyer_id=: sets the lawyer id
      def add_helper_methods(klass, attribute)
        association = self
        
        klass.class_eval do 
          # address.lawyer_id
          define_method("#{attribute}_id") do
            prefix_options["#{attribute}_id".intern]
          end
          
          # address.lawyer_id = 3
          define_method("#{attribute}_id=") do |value|
            prefix_options["#{attribute}_id".intern] = value
          end

          # address.lawyer
          define_method(attribute) do
            # if the parent has its own belongs_to associations, we need
            # to add those to the 'find' call. So, let's grab all of
            # these associations, turn them into a hash of :attr_name =>
            # attr_id, and fire off the find.
            
            unless instance_variable_get("@#{attribute}")
              object = association.resolve_relationship(self)
              instance_variable_set("@#{attribute}", object)
            end
            instance_variable_get("@#{attribute}")
          end
        end
        
        # Recurse through the parent object.
        associated_class.belongs_to.each do |parent_attribute|
          parent_attribute.add_helper_methods(klass, parent_attribute.attribute)
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

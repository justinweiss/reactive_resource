require 'active_resource'

module ReactiveResource
  
  # The class that all ReactiveResourse resources should inherit
  # from. This class fixes and patches over a lot of the broken stuff in
  # Active Resource, and the differences between the client-side Rails
  # REST stuff and the server-side Rails REST stuff.
  class Base < ActiveResource::Base
    extend Extensions::RelativeConstGet
    # Call this method to transform a resource into a 'singleton'
    # resource. This will fix the paths Active Resource generates for
    # singleton resources. See
    # https://rails.lighthouseapp.com/projects/8994/tickets/4348-supporting-singleton-resources-in-activeresource
    # for more info.
    def self.singleton
      @singleton = true
    end

    # +true+ if this resource is a singleton resource
    def self.singleton?
      @singleton
    end
    
    # Active Resource's find_one is broken if you don't pass a :from,
    # which makes absolutely no sense if you're working with a singleton
    # model and trying to generate URLs that Rails' REST support can
    # recognize. And thus we come to this:
    def self.find_one(options)
      found_object = super(options)
      if !found_object && singleton?
        prefix_options, query_options = split_options(options[:params])
        path = element_path(nil, prefix_options, query_options)
        found_object = instantiate_record(connection.get(path, headers), prefix_options)
      end
      found_object
    end
    
    # Override ActiveResource, because collection name is singular for
    # singleton resources.
    def self.collection_name
      if singleton?
        element_name
      else
        super
      end
    end

    # This method differs from its parent by adding association_prefix
    # into the generated url. This is needed to support belongs_to
    # associations.
    def self.collection_path(prefix_options = {}, query_options = nil)
      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      "#{prefix(prefix_options)}#{association_prefix(prefix_options)}#{collection_name}.#{format.extension}#{query_string(query_options)}"
    end

    # Same as collection_path, except with an extra +method_name+
    def self.custom_method_collection_url(method_name, options = {})
      prefix_options, query_options = split_options(options)
      "#{prefix(prefix_options)}#{association_prefix(prefix_options)}#{collection_name}/#{method_name}.#{format.extension}#{query_string(query_options)}"
    end

    # This is overridden to support nested urls for belongs_to
    # associations and removing IDs for singleton resources
    def self.element_path(id, prefix_options = {}, query_options = nil)
      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      element_path = "#{prefix(prefix_options)}#{association_prefix(prefix_options)}#{collection_name}"
      
      # singleton resources don't have an ID
      if id || !singleton?
        element_path += "/#{id}"
      end
      element_path += ".#{format.extension}#{query_string(query_options)}"
      element_path
    end

    # It's kind of redundant to have the server return the foreign
    # keys corresponding to the belongs_to associations (since they'll
    # be in the URL anyway), so we have to try to inject them based on
    # the current object's attributes. Otherwise, we'll lose these
    # keys after we save an object.
    def load(attributes)
      self.class.belongs_to_with_parents.each do |belongs_to_param|
        attributes["#{belongs_to_param}_id".intern] ||= prefix_options["#{belongs_to_param}_id".intern]
      end
      super(attributes)
    end

    # Add all of the belongs_to attributes as prefix parameters. This is
    # necessary to support nested url generation on our polymorphic
    # associations, because we need some way of getting the attributes
    # at the point where we need to generate the url, and only the
    # prefix options are available for both finds and creates.
    def self.prefix_parameters
      if !@prefix_parameters
        @prefix_parameters = super

        @prefix_parameters.merge(belongs_to_with_parents.map {|p| "#{p}_id".to_sym})
      end
      @prefix_parameters
    end

    # Necessary to support polymorphic nested resources. For example, a
    # license with params :lawyer_id => 2 will return 'lawyers/2/' and a
    # phone with params :address_id => 2, :lawyer_id => 3 will return
    # 'lawyers/3/addresses/2/'.
    def self.association_prefix(options)
      options = options.dup
      association_prefix = ''
      parent_prefix = ''
      
      if belongs_to
        # Recurse to add the parent resource hierarchy. For Phone, for
        # instance, this will add the '/lawyers/:id' part of the URL,
        # which it knows about from the Address class.
        parents.each do |parent|
          parent_prefix = parent.association_prefix(options) if parent_prefix.blank?
        end

        belongs_to.each do |association|
          param = association.attribute
          if association_prefix.blank? && param_value = options.delete("#{param}_id".intern) # only take the first one
            association_prefix = "#{param.to_s.pluralize}/#{param_value}/"
          end
        end
      end
      parent_prefix + association_prefix
    end

    # Add a parent-child relationship between +attribute+ and this
    # class. This allows parameters like +attribute_id+ to contribute to
    # generating nested urls.
    def self.belongs_to(attribute = nil, options = {})
      @belongs_to ||= []
      if attribute
        @belongs_to << Association::BelongsToAssociation.new(self, attribute, options)
      end
      @belongs_to
    end

    # Add a has_many relationship to another class.
    def self.has_many(attribute = nil, options = {})
      @has_many ||= []
      if attribute
        @has_many << Association::HasManyAssociation.new(self, attribute, options)
      end
      @has_many
    end

    # Add a has_one relationship to another class.
    def self.has_one(attribute = nil, options = {})
      @has_one ||= []
      if attribute
        @has_one << Association::HasOneAssociation.new(self, attribute, options)
      end
      @has_one
    end

    # merges in all of this class' associated classes' belongs_to
    # associations, so we can handle deeply nested routes. So, for
    # instance, if we have phone => address => lawyer, phone will look
    # for address' belongs_to associations and merge them in. This
    # allows us to have both lawyer_id and address_id at url generation
    # time.
    def self.belongs_to_with_parents
      belongs_to.map(&:associated_attributes).flatten.uniq
    end

    # All the classes that this class references in its +belongs_to+,
    # along with their parents, and so on.
    def self.parents
      @parents ||= belongs_to.map(&:associated_class)
    end

  end
end

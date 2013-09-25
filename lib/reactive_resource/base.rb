require 'active_resource'
require 'active_support/all'

module ReactiveResource

  # The class that all ReactiveResourse resources should inherit
  # from. This class fixes and patches over a lot of the broken stuff
  # in Active Resource, and smoothes out the differences between the
  # client-side Rails REST stuff and the server-side Rails REST stuff.
  # It also adds support for ActiveRecord-like associations.
  class Base < ActiveResource::Base
    extend Extensions::RelativeConstGet
    class_attribute :singleton_resource

    # Call this method to transform a resource into a 'singleton'
    # resource. This will fix the paths Active Resource generates for
    # singleton resources. See
    # https://rails.lighthouseapp.com/projects/8994/tickets/4348-supporting-singleton-resources-in-activeresource
    # for more info.
    def self.singleton
      self.singleton_resource = true
    end

    # +true+ if this resource is a singleton resource, +false+
    # otherwise
    def self.singleton?
      self.singleton_resource?
    end

    # Active Resource's find_one does nothing if you don't pass a
    # +:from+ parameter. This doesn't make sense if you're dealing
    # with a singleton resource, so if we don't get anything back from
    # +find_one+, try hitting the element path directly
    def self.find_one(options)
      found_object = super(options)
      if !found_object && singleton?
        prefix_options, query_options = split_options(options[:params])
        path = element_path(nil, prefix_options, query_options)
        found_object = instantiate_record(format.decode(connection.get(path, headers).body), prefix_options)
      end
      found_object
    end

    # Override ActiveResource's +collection_name+ to support singular
    # names for singleton resources.
    def self.collection_name
      if singleton?
        element_name
      else
        super
      end
    end

    # Returns the extension based on the format ('.json', for
    # example), or the empty string if +format+ doesn't specify an
    # extension
    def self.extension
      format.extension.blank? ? "" : ".#{format.extension}"
    end

    # This method differs from its parent by adding association_prefix
    # into the generated url. This is needed to support belongs_to
    # associations.
    def self.collection_path(prefix_options = {}, query_options = nil)
      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      "#{prefix(prefix_options)}#{association_prefix(prefix_options)}#{collection_name}#{extension}#{query_string(query_options)}"
    end

    # Same as collection_path, except with an extra +method_name+ on
    # the end to support custom methods
    def self.custom_method_collection_url(method_name, options = {})
      prefix_options, query_options = split_options(options)
      "#{prefix(prefix_options)}#{association_prefix(prefix_options)}#{collection_name}/#{method_name}#{extension}#{query_string(query_options)}"
    end

    # Same as collection_path, except it adds the ID to the end of the
    # path (unless it's a singleton resource)
    def self.element_path(id, prefix_options = {}, query_options = nil)
      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      element_path = "#{prefix(prefix_options)}#{association_prefix(prefix_options)}#{collection_name}"

      # singleton resources don't have an ID
      if id.present? || !singleton?
        element_path += "/#{id}"
      end
      element_path += "#{extension}#{query_string(query_options)}"
      element_path
    end

    # It's kind of redundant to have the server return the foreign
    # keys corresponding to the belongs_to associations (since they'll
    # be in the URL anyway), so we'll try to inject them based on the
    # attributes of the object we just used.
    def load(*attrs)
      attributes = attrs.first
      attributes = attributes ? attributes.stringify_keys : {}
      self.class.belongs_to_with_parents.each do |belongs_to_param|
        attributes["#{belongs_to_param}_id"] ||= prefix_options["#{belongs_to_param}_id".intern]

        # also set prefix attributes as real attributes. Otherwise,
        # belongs_to attributes will be stripped out of the response
        # even if we aren't actually using the association.
        @attributes["#{belongs_to_param}_id"] = attributes["#{belongs_to_param}_id"]
      end
      attrs[0] = attributes
      super(*attrs)
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

    # Returns a list of the belongs_to associations we will use to
    # generate the full path for this resource.
    def self.prefix_associations(options)
      options = options.dup
      used_associations = []
      parent_associations = []

      # Recurse to add the parent resource hierarchy. For Phone, for
      # instance, this will add the '/lawyers/:id' part of the URL,
      # which it knows about from the Address class.
      parents.each do |parent|
        parent_associations = parent.prefix_associations(options)
        break unless parent_associations.empty?
      end

      # The association chain we're following
      used_association = nil

      belongs_to_associations.each do |association|
        if !used_association && (association.associated_class.singleton? || param_value = options.delete("#{association.attribute}_id".intern)) # only take the first one
          used_associations << association
          break
        end
      end
      parent_associations + used_associations
    end

    # Generates the URL prefix that the belongs_to parameters and
    # associations refer to. For example, a license with params
    # :lawyer_id => 2 will return 'lawyers/2/' and a phone with params
    # :address_id => 2, :lawyer_id => 3 will return
    # 'lawyers/3/addresses/2/'.
    def self.association_prefix(options)
      options = options.dup
      association_prefix = ''

      if belongs_to_associations

        used_associations = prefix_associations(options)

        association_prefix = used_associations.map do |association|
          collection_name = association.associated_class.collection_name
          if association.associated_class.singleton?
            collection_name
          else
            value = options.delete("#{association.attribute}_id".intern)
            "#{collection_name}/#{value}"
          end
        end.join('/')

        # add trailing slash
        association_prefix << '/' unless used_associations.empty?
      end
      association_prefix
    end

    class << self
      # Holds all the associations that have been declared for this class
      attr_accessor :associations
    end
    self.associations = []

    # Add a has_one relationship to another class. +options+ is a hash
    # of extra parameters:
    #
    # [:class_name] Override the class name of the target of the
    #               association. By default, this is based on the
    #               attribute name.
    def self.has_one(attribute, options = {})
      self.associations << Association::HasOneAssociation.new(self, attribute, options)
    end

    # Add a has_many relationship to another class. +options+ is a hash
    # of extra parameters:
    #
    # [:class_name] Override the class name of the target of the
    #               association. By default, this is based on the
    #               attribute name.
    def self.has_many(attribute, options = {})
      self.associations << Association::HasManyAssociation.new(self, attribute, options)
    end

    # Add a parent-child relationship between +attribute+ and this
    # class. This allows parameters like +attribute_id+ to contribute
    # to generating nested urls. +options+ is a hash of extra
    # parameters:
    #
    # [:class_name] Override the class name of the target of the
    #               association. By default, this is based on the
    #               attribute name.
    def self.belongs_to(attribute, options = {})
      self.associations << Association::BelongsToAssociation.new(self, attribute, options)
    end

    # Returns all of the belongs_to associations this class has.
    def self.belongs_to_associations
      self.associations.select {|assoc| assoc.kind_of?(Association::BelongsToAssociation) }
    end

    # Fix up the +klass+ attribute of all of our associations to point
    # to the new child class instead of the parent class, so class
    # lookup works as expected
    def self.inherited(child)
      super(child)
      child.associations = []
      associations.each do |association|
        begin
          child.associations << association.class.new(child, association.attribute, association.options)
        rescue NameError
          # assume that they'll fix the association later by manually specifying :class_name in the belongs_to
        end
      end
    end

    # ActiveResource (as of 3.0) assumes that you have a to_x method
    # on ActiveResource::Base for any format 'x' that is assigned to
    # the record. This seems weird -- the format should take care of
    # encoding, not the object itself. To keep this as stable as
    # possible, we should use to_x if it's defined, otherwise just
    # delegate to the format's 'encode' function. This is how things
    # worked as of Rails 2.3.
    def encode(options = {})
      if defined?(ActiveResource::VERSION) && ActiveResource::VERSION::MAJOR == 3
        if respond_to?("to_#{self.class.format.extension}")
          super(options)
        else
          self.class.format.encode(attributes, options)
        end
      else
        super(options)
      end
    end

    # In order to support two-way belongs_to associations in a
    # reasonable way, we duplicate all of the prefix options as real
    # attributes (so license.lawyer_id will set both the lawyer_id
    # attribute and the lawyer_id prefix option). When we're ready to
    # save, we should take all the parameters that we're already
    # sending as prefix options and remove them from the model's
    # attributes so we don't send duplicates down the wire. This way,
    # if you have an object that belongs_to :lawyer and belongs_to
    # :phone (in that order), setting lawyer_id and phone_id will
    # treat lawyer_id as a prefix option and phone_id as a normal
    # attribute.
    def save
      if self.class.belongs_to_associations
        used_attributes = self.class.prefix_associations(prefix_options).map {|association| association.attribute}
        used_attributes.each do |attribute|
          attributes.delete("#{attribute}_id".intern)
        end
      end
      super
    end

    # belongs_to in ReactiveResource works a little differently than
    # ActiveRecord. Because we have to deal with full class hierachies
    # in order to generate the full URL (as mentioned in
    # association_prefix), we have to treat the belongs_to
    # associations on objects that this object belongs_to as if they
    # exist on this object itself. This method merges in all of this
    # class' associated classes' belongs_to associations, so we can
    # handle deeply nested routes. So, for instance, if we have phone
    # \=> address => lawyer, phone will look for address' belongs_to
    # associations and merge them in. This allows us to have both
    # lawyer_id and address_id at url generation time.
    def self.belongs_to_with_parents
      @belongs_to_with_parents ||= begin
        ret = belongs_to_associations.map(&:associated_attributes)
        ret += parents.map(&:belongs_to_with_parents)
        ret.flatten.uniq
      end
    end

    # All the classes that this class references in its +belongs_to+,
    # along with their parents, and so on.
    def self.parents
      @parents ||= belongs_to_associations.map(&:associated_class)
    end

    private

    # Same as element_path, except with an extra +method_name+ on
    # the end to support custom methods
    def custom_method_element_url(method_name, options = {})
      prefix_options, query_options = split_options(options)
      "#{self.class.prefix(prefix_options)}#{self.class.association_prefix(prefix_options)}#{self.class.collection_name}/#{id}/#{method_name}#{self.class.extension}#{self.class.__send__(:query_string, query_options)}"
    end
    def custom_method_new_element_url(method_name, options = {})
      prefix_options, query_options = split_options(options)
      "#{self.class.prefix(prefix_options)}#{self.class.association_prefix(prefix_options)}#{self.class.collection_name}/new/#{method_name}#{self.class.extension}#{self.class.__send__(:query_string, query_options)}"
    end

  end
end

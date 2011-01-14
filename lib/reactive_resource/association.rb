module ReactiveResource 
  module Association # :nodoc:
    autoload :BelongsToAssociation, 'reactive_resource/association/belongs_to_association'
    autoload :HasManyAssociation, 'reactive_resource/association/has_many_association'
    autoload :HasOneAssociation, 'reactive_resource/association/has_one_association'
  end
end

class ReactiveResource::Base
  self.site = "https://api.avvo.com/"
  self.prefix = "/api/1/"
  self.format = :json
end

class ReactiveResource::Lawyer < ReactiveResource::Base
  has_one :headshot
  has_many :addresses
end

# half the complications in here come from the fact that we have
# resources shared with one of two different types of parents
class ReactiveResource::Doctor < ReactiveResource::Base
  has_one :headshot
  has_many :addresses
end

class ReactiveResource::Headshot < ReactiveResource::Base
  singleton
  belongs_to :lawyer
  belongs_to :doctor
end

class ReactiveResource::Address < ReactiveResource::Base
  belongs_to :lawyer
  belongs_to :doctor
  has_many :phones
end

module ChildResource
  
  class Address < ReactiveResource::Address
    belongs_to :lawyer, :class_name => "ReactiveResource::Lawyer"
    belongs_to :doctor, :class_name => "ReactiveResource::Doctor"
  end

  class Phone < ReactiveResource::Address
  end
end

class ReactiveResource::Phone < ReactiveResource::Base
  belongs_to :address
end

module ActiveResource
  module Formats
    module NoFormatFormat
      extend ActiveResource::Formats::JsonFormat
      extend self
      def extension
        ''
      end
    end
  end
end

class ReactiveResource::NoExtension < ReactiveResource::Base
  self.format = :no_format
end

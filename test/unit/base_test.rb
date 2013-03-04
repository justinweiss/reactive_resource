require 'test_helper'

class ReactiveResource::BaseTest < Test::Unit::TestCase

  context "A resource that inherits from another resource" do
    setup do
      @object = ChildResource::Address.new
    end

    should "inherit its parents' associations" do
      assert_contains @object.class.associations.map(&:attribute), :phones
    end

    should "prefer to resolve to another child class" do
      assert_equal ChildResource::Phone, @object.class.associations.detect {|assoc| assoc.attribute == :phones }.associated_class
    end

    should "follow relationships where :class_name is specified" do
      assert_equal ReactiveResource::Lawyer, @object.class.associations.detect {|assoc| assoc.attribute == :lawyer }.associated_class
    end

    should "return valid path when id is blank" do
      assert_equal "/api/1/headshot.json", ReactiveResource::Headshot.element_path('')
    end
  end

  context "A resource that inherits from ReactiveResource::Base" do

    setup do
      @object = ReactiveResource::Lawyer.new
    end

    should "hit the Avvo API with the correct URL when saved" do
      stub_request(:post, "https://api.avvo.com/api/1/lawyers.json")
      @object.save
      assert_requested(:post, "https://api.avvo.com/api/1/lawyers.json")
    end

    should "hit the Avvo API with the correct URL when retrieved" do 
      stub_request(:get, "https://api.avvo.com/api/1/lawyers/1.json")\
        .to_return(:body => {:lawyer => {:id => '1'}}.to_json)
      ReactiveResource::Lawyer.find(1)
      assert_requested(:get, "https://api.avvo.com/api/1/lawyers/1.json")      
    end

    context "with a has_many relationship to another object" do
      should "hit the associated object's URL with the correct parameters when requested" do
        stub_request(:get, "https://api.avvo.com/api/1/lawyers/1/addresses.json")\
          .to_return(:body => [{:address => {:id => 1}}].to_json)
        @object.id = 1
        @object.addresses
        assert_requested(:get, "https://api.avvo.com/api/1/lawyers/1/addresses.json")
      end
    end

    context "with a has_one relationship to another object" do
      should "hit the associated object's URL with the correct parameters when requested" do
        stub_request(:get, "https://api.avvo.com/api/1/lawyers/1/headshot.json")\
          .to_return(:body => {:headshot => {:headshot_url => "blah"}}.to_json)
        @object.id = 1
        @object.headshot
        assert_requested(:get, "https://api.avvo.com/api/1/lawyers/1/headshot.json")
      end
    end

    context "with a belongs_to association and correct parameters" do
      setup do 
        @object = ReactiveResource::Address.new(:lawyer_id => 2)
      end

      should "hit the Avvo API with the correct URL when saved" do
        stub_request(:post, "https://api.avvo.com/api/1/lawyers/2/addresses.json")
        @object.save
        assert_requested(:post, "https://api.avvo.com/api/1/lawyers/2/addresses.json")
      end

      should "hit the Avvo API with the correct URL when retrieved" do 
        stub_request(:get, "https://api.avvo.com/api/1/lawyers/2/addresses/3.json")\
          .to_return(:body => {:address => {:id => '3'}}.to_json)
        ReactiveResource::Address.find(3, :params => {:lawyer_id => 2})
        assert_requested(:get, "https://api.avvo.com/api/1/lawyers/2/addresses/3.json")
      end

      should "hit the Avvo API with the correct URL when updated" do 
        stub_request(:get, "https://api.avvo.com/api/1/lawyers/2/addresses/3.json")\
          .to_return(:body => {:address => {:id => '3'}}.to_json)
        license = ReactiveResource::Address.find(3, :params => {:lawyer_id => 2})
        assert_requested(:get, "https://api.avvo.com/api/1/lawyers/2/addresses/3.json")  
        stub_request(:put, "https://api.avvo.com/api/1/lawyers/2/addresses/3.json")
        license.save
        assert_requested(:put, "https://api.avvo.com/api/1/lawyers/2/addresses/3.json")
      end

      should "set the prefix parameters correctly when saved" do
        stub_request(:post, "https://api.avvo.com/api/1/lawyers/2/addresses.json")\
          .to_return(:body => {:address => {:id => '2'}}.to_json)
        @object.save
        assert_requested(:post, "https://api.avvo.com/api/1/lawyers/2/addresses.json")

        assert_equal "/api/1/lawyers/2/addresses/2.json", @object.send(:element_path)
      end
      
    end

    context "with a belongs_to hierarchy and correct parameters" do 

      setup do 
        @object = ReactiveResource::Phone.new(:doctor_id => 2, :address_id => 3)
      end

      should "allow setting the prefix options after creation" do
        @object = ReactiveResource::Phone.new
        @object.doctor_id = 2
        @object.address_id = 3
        stub_request(:post, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones.json")
        @object.save
        assert_requested(:post, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones.json")
      end

      should "allow following +belongs_to+ associations" do
        @object = ReactiveResource::Phone.new
        @object.doctor_id = 2
        @object.address_id = 3
        assert_equal 3, @object.address_id
        stub_request(:get, "https://api.avvo.com/api/1/doctors/2/addresses/3.json")\
          .to_return(:body => {:address => {:id => '3'}}.to_json)
        @object.address
        @object.address
        assert_requested(:get, "https://api.avvo.com/api/1/doctors/2/addresses/3.json", :times => 1)
      end
      
      should "hit the Avvo API with the correct URL when saved" do
        stub_request(:post, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones.json")
        @object.save
        assert_requested(:post, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones.json")
      end

      should "hit the Avvo API with the correct URL when updated" do 
        stub_request(:get, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones/4.json")\
          .to_return(:body => {:address => {:id => '4'}}.to_json)
        phone = ReactiveResource::Phone.find(4, :params => {:doctor_id => 2, :address_id => 3})
        assert_requested(:get, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones/4.json")

        stub_request(:put, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones/4.json")
        phone.save
        assert_requested(:put, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones/4.json")
      end

      should "set the prefix parameters correctly when saved" do
        stub_request(:post, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones.json").to_return(:body => {:phone_type_id => 2, :id => 4, :phone_number=>"206-728-0588"}.to_json)
        @object.save
        assert_requested(:post, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones.json")

        assert_equal "/api/1/doctors/2/addresses/3/phones/4.json", @object.send(:element_path)
      end

      should "hit the Avvo API with the correct URL when retrieved" do 
        stub_request(:get, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones/4.json")\
          .to_return(:body => {:phone => {:id => '4'}}.to_json)
        ReactiveResource::Phone.find(4, :params => {:doctor_id => 2, :address_id => 3})
        assert_requested(:get, "https://api.avvo.com/api/1/doctors/2/addresses/3/phones/4.json")      
      end
    end

    context "with custom methods" do

      should "hit the correct collection urls" do
        stub_request(:post, "https://api.avvo.com/api/1/lawyers/search.json")\
          .to_return(:body => {:lawyers => [{:id => 2}, {:id => 4}]}.to_json)
        ReactiveResource::Lawyer.post(:search, {}, {:first_name => "Bob"})
        assert_requested(:post, "https://api.avvo.com/api/1/lawyers/search.json")
      end

      should "hit the correct nested collection url" do
        stub_request(:post, "https://api.avvo.com/api/1/lawyers/1/addresses/search.json")\
          .to_return(:body => {:addresses => [{:id => 1}, {:id => 3}]}.to_json)
        ReactiveResource::Address.post(:search, {:lawyer_id => 1}, {:street_name => "21st Ave NE"})
        assert_requested(:post, "https://api.avvo.com/api/1/lawyers/1/addresses/search.json")
      end

      should "hit the correct member urls" do
        stub_request(:get, "https://api.avvo.com/api/1/lawyers/1/billing_plan.json")\
          .to_return(:body => {:billing_plan => {:type => "hourly", :rate => "200"}}.to_json)
        @object.id = 1
        @object.get(:billing_plan, {})
        assert_requested(:get, "https://api.avvo.com/api/1/lawyers/1/billing_plan.json")
      end
    end

  end

  context "A resource without an extension" do
    should "hit the correct urls" do
      stub_request(:get, "https://api.avvo.com/api/1/no_extensions")\
        .to_return(:body => [].to_json)
      @object = ReactiveResource::NoExtension.find(:all)
      assert_requested(:get, "https://api.avvo.com/api/1/no_extensions")

      stub_request(:post, "https://api.avvo.com/api/1/no_extensions")
      @object = ReactiveResource::NoExtension.new(:id => 1).save
      assert_requested(:post, "https://api.avvo.com/api/1/no_extensions")

      stub_request(:get, "https://api.avvo.com/api/1/no_extensions/test")\
        .to_return(:body => {:test => {:id => 1}}.to_json)
      @object = ReactiveResource::NoExtension.get(:test)
      assert_requested(:get, "https://api.avvo.com/api/1/no_extensions/test")
    end
  end

  context "A resource with a two-way belongs to association" do
    should "convert unused prefix options to attributes" do
      stub_request(:post, "https://api.avvo.com/api/1/lawyers/1/lawyer_posts.json").
        with(:body => {"lawyer_post" => {"post_id" => 2}})
      @object = ReactiveResource::LawyerPost.new(:lawyer_id => 1, :post_id => 2).save
      assert_requested(:post, "https://api.avvo.com/api/1/lawyers/1/lawyer_posts.json")
    end

    should "treat returned prefix parameters as regular parameters" do
      stub_request(:get, "https://api.avvo.com/api/1/lawyers/1/lawyer_posts.json").
        to_return(:body =>[{"id" => 1, "post_id" => 2}].to_json)
      stub_request(:put, "https://api.avvo.com/api/1/lawyers/1/lawyer_posts/1.json").
        with(:body => {"lawyer_post" => {"id" => 1, "post_id" => 3}})
      
      @object = ReactiveResource::LawyerPost.find(:all, :params => {:lawyer_id => 1}).first
      assert_not_nil @object.post_id

      @object.post_id = 3
      @object.save

      assert_requested(:put, "https://api.avvo.com/api/1/lawyers/1/lawyer_posts/1.json")
    end

    should "set the attributes correctly when it's created" do
      @object = ReactiveResource::LawyerPost.new(:lawyer_id => 1, :post_id => 2)
      assert_not_nil @object.attributes[:post_id]
      assert_not_nil @object.attributes[:lawyer_id]
    end

    should "set the attributes correctly when it's created with strings" do
      @object = ReactiveResource::LawyerPost.new("lawyer_id" => 1, "post_id" => 2)
      assert_not_nil @object.post_id
      assert_not_nil @object.attributes["post_id"]
      assert_not_nil @object.attributes[:lawyer_id]
    end
  end
  
end

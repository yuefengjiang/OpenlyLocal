require 'test_helper'

class CompanyTest < ActiveSupport::TestCase
  context "The Company class" do
    setup do
      @company = Factory(:company)
    end
  
    should have_many :supplying_relationships
  
    should have_db_column :title
    should have_db_column :company_number
    should have_db_column :url
    should have_db_column :normalised_title
    should have_db_column :status
    should have_db_column :wikipedia_url
    should have_db_column :company_type
    should have_db_column :incorporation_date
    should have_db_column :vat_number
    should have_db_column :previous_names
    should have_db_column :sic_codes
    should have_db_column :country
    
    should 'serialize previous_names' do
      assert_equal ['foo', 'bar'], Factory(:company, :previous_names => ['foo', 'bar']).reload.previous_names 
    end

    should 'serialize sic_codes' do
      assert_equal ['foo', 'bar'], Factory(:company, :sic_codes => ['foo', 'bar']).reload.sic_codes 
    end

    should 'mixin AddressMethods module' do
      assert @company.respond_to?(:address_in_full)
    end
    
    should 'mixin SpendingStatUtilities::Base' do
      assert @company.respond_to?(:spending_stat)
    end
    
    should 'have many financial_transactions through supplying_relationships' do
      supplier = Factory(:supplier, :payee => @company)
      ft = Factory(:financial_transaction, :supplier => supplier)
      assert_equal [ft], @company.financial_transactions
    end
    
    context "when validating" do
      should "require presence of title on create" do
        co = Factory.build(:company, :title => nil)
        assert !co.valid?
        assert co.errors[:title]
        # This bit can be deleted when we no longer have companies without titles
        @company.update_attribute(:title, nil)
        assert @company.valid?
      end
      
      should "require presence of company_number or vat_number" do
        company = Factory.build(:company, :company_number => '1234')
        assert company.valid?
        company.attributes = {:company_number => nil, :vat_number => 'ab123'}
        assert company.valid?
        company.vat_number = nil
        assert !company.valid?
      end
      
      should "validate uniqueness of non-blank company_number" do
        dup_company = Factory.build(:company, :company_number => @company.company_number)
        another_dup_company = Factory.build(:company, :company_number => nil, :vat_number => 'cd456')
        assert !dup_company.valid?
        assert_equal 'has already been taken', dup_company.errors[:company_number]
        @company.update_attributes(:company_number => nil, :vat_number => 'ab123' )
        assert another_dup_company.valid?
      end
      
      should "validate uniqueness of non-blank vat_number scoped to company_number" do
        dup_company = Factory.build(:company, :company_number => '4567') # vat number is nil, so is @company
        another_dup_company = Factory.build(:company, :company_number => nil, :vat_number => 'ab123')
        
        assert dup_company.valid? # don't check if nil
        
        @company.update_attribute(:vat_number, 'ab123' )
        assert another_dup_company.valid? # vat number is smae, company number is different
        
        @company.update_attribute(:company_number, nil ) # vat number is smae, company number is no longer unique (another one with nil)
        assert !another_dup_company.valid?
        
        assert_equal 'has already been taken', another_dup_company.errors[:vat_number]
      end
      
      # should_validate_uniqueness_of :company_number
      # should_validate_uniqueness_of(:vat_number).case_insensitive
    end
    
    context "after creation" do
      setup do
        Delayed::Job.stubs(:enqueue)# because spending stat also queued
      end

      should "add company to Delayed::Job queue for processing" do
        Delayed::Job.expects(:enqueue).with(kind_of(Company))
        Factory(:company)
      end
    end
    
    context "after saving" do

      should "not add company to Delayed::Job queue for processing" do
        Delayed::Job.expects(:enqueue).never
        @company.save!
      end
    end
    
    context "when normalising title" do
      
      should "return nil if blank" do
        assert_nil Company.normalise_title(nil)
        assert_nil Company.normalise_title('')
      end
      
      should "normalise title" do
        TitleNormaliser.expects(:normalise_company_title).with('foo bar')
        Company.normalise_title('foo bar')
      end
      
      should "replace '&' with 'and'" do
        # this is regression test as this is now in TitleNormaliser
        assert_equal 'foo and bar', Company.normalise_title('foo & bar')
      end
      
      should "replace '&' with no space with space-separated 'and'" do
        # this is regression test as this is now in TitleNormaliser
        # TitleNormaliser.expects(:normalise_company_title).with('foo and bar')
        assert_equal 'foo and bar', Company.normalise_title('foo&bar')
      end
      
      # should "remove Ltd or Limited or PLC etc" do
      #   TitleNormaliser.expects(:normalise_company_title).with('foo and bar limited')
      #   Company.normalise_title('foo&bar')
      # end
    end
    
    context "when normalising company_number" do
      should "add required leading zeros" do
        assert_equal '00001234', Company.normalise_company_number('1234')
        assert_equal '00001234', Company.normalise_company_number('001234')
      end
      
      should "return nil if company_number blank" do
        assert_nil Company.normalise_company_number(nil)
        assert_nil Company.normalise_company_number('')
      end
      
      should "not change company numbers with letters in them" do
        assert_equal 'FO12345', Company.normalise_company_number('FO12345')
      end
      
    end
    
    context "when returning whether probable company" do
      
      should "return false if blank" do
        assert !Company.probable_company?(nil)
        assert !Company.probable_company?('')
      end
      
      should "match based on company-likelness of name" do
        probable_companies = ['Foo Ltd', 'Foo Limited', 'Foo PLC', 'Foo Ltd.', 'Foo PLC', 'Foo P.L.C', 'Foo plc', 'Foo Private Limited Company', 'Foo Public Limited Company',
          'Foo Private Unlimited Company', 'Foo Limited Partnership', 'Foo Community Interest Company', 'Foo LLP', 'Foo Limited Liability Partnership']
        unlikely_companies = ['Unlimited Foo', 'Foo']
        probable_companies.each do |co_name|
          assert Company.probable_company?(co_name), "Failed to identify #{co_name} as probable_company"
        end
        
        unlikely_companies.each do |co_name|
          assert !Company.probable_company?(co_name), "Wrongly identified #{co_name} as probable_company"
        end
      end
    end
    
    context "when getting from title" do
      should "find company that matches normalised title" do
        raw_title = ' Foo &  Bar Ltd.'
        Company.expects(:first).with(:conditions => {:normalised_title => TitleNormaliser.normalise_company_title(raw_title)}).returns(stub_everything)
        Company.from_title(raw_title)
      end
      
      should "return company that matching normalised title" do
        some_co = stub
        Company.stubs(:first).returns(some_co)
        assert_equal some_co, Company.from_title('Foo')
      end
      
      context "and no company matches normalised title" do
        setup do
          @company_attribs = {:status=>"Active", :company_number=>"06398324", :title=>"SPIKES CAVELL & COMPANY LIMITED", :company_type=>"Private Limited Company", :address_in_full=>"1 NORTHBROOK PLACE\nNEWBURY\nBERKSHIRE\nRG14 1DQ", :incorporation_date=>"2007-10-15"}
          CompanyUtilities::Client.any_instance.stubs(:find_company_by_name).returns(@company_attribs)
        end

        should "get company matching name" do
          CompanyUtilities::Client.any_instance.expects(:find_company_by_name).with('Foo')
          Company.from_title('Foo')
        end
        
        should "create company" do
          assert_difference "Company.count", 1 do
            Company.from_title('Foo')
          end
        end
        
        should "return created company" do
          company = Company.from_title('Foo')
          assert !company.new_record?
          assert_kind_of Company, company
          assert_equal "SPIKES CAVELL & COMPANY LIMITED", company.title
          assert_equal "06398324", company.company_number
        end
        
        context "and no_create param passed" do

          should "not create company if no_create param passed" do
            assert_no_difference "Company.count" do
              Company.from_title('Foo', :no_create => true)
            end
          end
          
          should "return company_info" do
            assert_equal @company_attribs, Company.from_title('Foo', :no_create => true)
          end
        end
        
        context "and company returned has same company_number as existing company" do
          setup do
            @exist_co = Factory(:company, :title => 'Foo and Bar', :company_number => '06398324') #no limited
            exist_co_attribs = {:status=>"Active", :company_number=>"06398324", :title=>"Foo and Bar", :company_type=>"Private Limited Company", :incorporation_date=>"2007-10-15"}
            CompanyUtilities::Client.stubs(:find_company_by_name).with('Foo and Bar Limited').returns(exist_co_attribs)
          end

          should "not create company" do
            assert_no_difference "Company.count" do
              Company.from_title('Foo and Bar Limited')
            end
          end
          
          should "return existing company" do
            assert_equal @exist_co, Company.from_title('Foo and Bar Limited')
          end
          
          should "return existing company even if no_create is true" do
            assert_equal @exist_co, Company.from_title('Foo and Bar Limited', :no_create => true)
          end
        end

        context "but no company is returned" do
          setup do
            CompanyUtilities::Client.any_instance.stubs(:find_company_by_name) # => returns nil still
          end
        
          should "not create company" do
            assert_no_difference "Company.count" do
              Company.from_title('Foo')
            end
          end
        end
      end
    end
        
    context "when matching or creating from params" do
      setup do
        @existing_company = Factory(:company, :company_number => "00012345")
        @existing_co_with_vat_no = Factory(:company, :company_number => nil, :vat_number => '1234')
      end

      should "return company with given company number" do
        assert_equal @existing_company, Company.match_or_create(:company_number => "00012345")
      end
      
      should "not change title of existing company with given company number" do
        exist_title = @existing_company.title
        Company.match_or_create(:company_number => "00012345", :title => 'New Title')
        assert_equal exist_title, @existing_company.reload.title
      end
      
      should "return company with given vat number and normalised title" do
        assert_equal @existing_co_with_vat_no, Company.match_or_create(:vat_number => "1234", :title => 'Foo & Bar')
      end

      should "return company with given vat number" do
        assert_equal @existing_co_with_vat_no, Company.match_or_create(:vat_number => "1234")
      end
      
      should "return company that matches normalised version of company number" do
        assert_equal @existing_company, Company.match_or_create(:company_number => "12345")
        assert_equal @existing_company, Company.match_or_create(:company_number => "012345")
      end
      
      should "not add company to delayed_job queue for fetching more details" do
        Delayed::Job.expects(:enqueue).never
        Company.match_or_create(:company_number => "012345")
      end
      
      context "and company doesn't exist" do
        
        should "create company with given company number and title" do
          assert_difference "Company.count", 1 do
            Company.match_or_create(:company_number => "07654321", :title => 'Foo Ltd')
          end
          assert c=Company.find_by_company_number("07654321")
          assert_equal 'Foo Ltd', c.title
        end
        
        should 'normalize company_number when creating company' do
          c = Company.match_or_create(:company_number => "7654321", :title => 'Foo Ltd')
          assert_equal "07654321", c.reload.company_number
        end
        
        should "create company with given vat_number and title" do
          assert_difference "Company.count", 1 do
            Company.match_or_create(:vat_number => "7654321", :title => 'Foo Ltd')
          end
          assert c=Company.find_by_vat_number("7654321")
          assert_equal 'Foo Ltd', c.title
        end
        
        should 'assign other attributes' do
          c = Company.match_or_create(:company_number => "7654321", :url => 'http://foo.com', :wikipedia_url => 'http://en.wikipedia.org/wiki/foo', :title => 'Foo Ltd')
          assert_equal 'http://foo.com', c.url
          assert_equal 'http://en.wikipedia.org/wiki/foo', c.wikipedia_url
        end
        
        should 'not create company number if no company number and no vat number' do
          c = Company.match_or_create(:url => 'http://foo.com', :wikipedia_url => 'http://en.wikipedia.org/wiki/foo', :title => 'Foo Ltd')
          assert_nil c.company_number
        end
        
        should 'add company to delayed_job queue for fetching more details' do
          Delayed::Job.stubs(:enqueue)# because spending stat also queued
          
          Delayed::Job.expects(:enqueue).with(kind_of(Company))
          Company.match_or_create(:company_number => "07654321", :title => 'Foo Ltd')
        end

      end
    end
    
  end
  
  context "An instance of the Company class" do
    setup do
      @company = Factory(:company)
      @company_with_no_title = Factory(:company)
      @company_with_no_title.title=nil
    end
    
    # context "when returning title" do
    #   
    #   should "use title attribute by default" do
    #     @company.update_attribute(:title, 'Foo Incorp')
    #     assert_equal 'Foo Incorp', @company.title
    #   end
    #   
    #   should "use company number if title is nil" do
    #     @company.title = nil
    #     assert_equal "Company number #{@company_with_no_title.company_number}", @company_with_no_title.title
    #   end
    #   
    #   should "use vat number if title and company_number is nil" do
    #     @company_with_no_title.attributes = {:company_number => nil, :vat_number => 'GB1234'}
    #     assert_equal "Company with VAT number GB1234", @company_with_no_title.title
    #   end
    # end
    
    should "use title when converting to_param" do
      @company.title = "some title-with/stuff"
      assert_equal "#{@company.id}-some-title-with-stuff", @company.to_param
    end
  
    should "skip title when converting to_param if title doesn't exist" do
      assert_equal @company_with_no_title.id.to_s, @company_with_no_title.to_param
    end
  
    context "when saving" do
      should "normalise title" do
        @company.expects(:normalise_title)
        @company.save!
      end
  
      should "save normalised title" do
        @company.title = "Foo & Baz Ltd."
        @company.save!
        assert_equal "foo and baz limited", @company.reload.normalised_title
      end
      
      # should "not save normalised title if title is nil" do
      #   @company.update(:title, nil)
      #   assert_nil @company.reload.normalised_title
      # end
      # 
      should "normalise company_number" do
        Company.expects(:normalise_company_number)
        @company.save!
      end
  
      should "save normalised company_number" do
        @company.company_number = "1234"
        @company.save!
        assert_equal "00001234", @company.reload.company_number
      end
      
      should "not save normalised company_number if nil" do
        @company.attributes = {:company_number => nil, :vat_number => '42'}
        @company.save!
        assert_nil @company.reload.company_number
      end
      
      
    end
    
    context "when returning resource_uri" do
      should 'return OpenCorporates uri for company' do
        assert_equal "http://opencorporates.com/id/companies/uk/#{@company.company_number}", @company.resource_uri
      end
    end
    
    context "when populating basic info" do
      
      context "and company has company_number" do
        setup do
          resp_hash = {:title => 'FOOCORP', :status => 'active', :status => 'Active', :incorporation_date => '1990-02-21', :company_type => 'Private Limited Company', :address_in_full => "501 BEAUMONT LEYS LANE\nLEICESTER\nLEICESTERSHIRE\nLE4 2BN" }
          CompanyUtilities::Client.any_instance.stubs(:company_details_for).returns(resp_hash)
        end

        should "fetch info using CompanyUtilities" do
          CompanyUtilities::Client.any_instance.expects(:company_details_for).with(@company.company_number)
          @company.populate_basic_info
        end

        should "update company with info from CompanyUtilities" do
          @company.populate_basic_info
          assert_equal 'FOOCORP', @company.title
          assert_equal '1990-02-21'.to_date, @company.incorporation_date
          assert_equal 'Private Limited Company', @company.company_type
          assert_equal 'Active', @company.status
        end

        should 'add address for company' do
          @company.populate_basic_info
          assert_kind_of Address, address = @company.address
          assert_equal "501 BEAUMONT LEYS LANE, LEICESTER, LEICESTERSHIRE, LE4 2BN", address.in_full
        end
      end
  
      context "and company has vat_number" do
        setup do
          @vat_company = Factory(:vat_no_company)
          @resp_hash = {:title => 'FOOCORP LTD', :address_in_full => "501 BEAUMONT LEYS LANE, LEICESTER, LEICESTERSHIRE, LE4 2BN" }
          CompanyUtilities::Client.any_instance.stubs(:get_vat_info).returns(@resp_hash)
        end

        should "fetch info from VAT Service using CompanyUtilities" do
          CompanyUtilities::Client.any_instance.expects(:get_vat_info).with(@vat_company.vat_number)
          @vat_company.populate_basic_info
        end
        
        should 'not raise exception if no info from VAT Service' do
          CompanyUtilities::Client.any_instance.expects(:get_vat_info).with(@vat_company.vat_number)
          assert_nothing_raised(Exception) { @vat_company.populate_basic_info }
        end
        
        should 'try to match using name returned by VAT service' do
          Company.expects(:from_title).with('FOOCORP LTD', :no_create => true)
          @vat_company.populate_basic_info
        end
        
        context "and if existing company returned after matching name" do
          setup do
            Factory(:supplier, :payee => @vat_company)
            @supplying_relationships = @vat_company.supplying_relationships
            @existing_company = Factory(:company, :company_number => "EC12345")
            Company.expects(:from_title).with('FOOCORP LTD', :no_create => true).returns(@existing_company)
          end

          should "delete VAT company" do
            assert_difference "Company.count", -1 do
              @vat_company.populate_basic_info
            end
            assert_nil Company.find_by_id(@vat_company.id)
          end
          
          should 'associate VAT company supplying relationships with existing company' do
            @vat_company.populate_basic_info
            assert @supplying_relationships.all?{ |s| s.payee == @existing_company }
          end
          
          should 'add VAT company vat_number to existing company' do
            @vat_company.populate_basic_info
            assert_equal @vat_company.vat_number, @existing_company.reload.vat_number
          end
        end

        context "and if company info returned after matching name" do
          setup do
            @company_attribs = {:status=>"Active", :company_number=>"06398324", :title=>"SPIKES CAVELL & COMPANY LIMITED", :company_type=>"Private Limited Company", :address_in_full=>"1 NORTHBROOK PLACE\nNEWBURY\nBERKSHIRE\nRG14 1DQ", :incorporation_date=>"2007-10-15"}
            Company.stubs(:from_title).returns(@company_attribs)
          end

          should "update vat company with company_info" do
            @vat_company.populate_basic_info
            assert_equal "06398324", @vat_company.company_number
            assert_equal "SPIKES CAVELL & COMPANY LIMITED", @vat_company.title
          end
        end
        
        context "and if no company info returned after matching name" do
          setup do
            Company.stubs(:from_title) # => returns nil
          end

          should "update vat company with vat info" do
            @vat_company.populate_basic_info
            assert_equal 'FOOCORP LTD', @vat_company.title
            assert_equal @resp_hash[:address_in_full], @vat_company.address_in_full
          end
        end
        
      end
  
    end
  
    should 'alias populate_basic_info as perform' do
      @company.expects(:populate_basic_info)
      @company.perform
    end
    
    context 'when returning opencorporates_url' do
      should "return url on opencorporates" do
        @company.company_number = '012345'
        assert_equal 'http://opencorporates.com/companies/uk/012345', @company.opencorporates_url
      end
    end
    
    context "when returning council_spending_breakdown" do
      setup do
        @councils = (1..20).collect do
          c = Factory(:generic_council)
          s = Factory(:supplier, :organisation => c, :payee => @company)
          Factory(:financial_transaction, :supplier => s)
          s.spending_stat.perform
          c.spending_stat.perform
        end
        # Factory(:spending_stat, :organisation => @company, :total_spend => 999999)
        @breakdown = @company.council_spending_breakdown
      end

      should "return an array of hashes" do
        assert_kind_of Array, @company.council_spending_breakdown
        assert_kind_of Hash, @company.council_spending_breakdown.first
      end
      
      context "and hash" do
        setup do
          @council_hash = @breakdown.first
        end
        should "contain council id" do
          assert @council_hash[:council_id]
        end
        should "contain total spend" do
          assert @council_hash[:total_spend]
        end
        should "contain average_monthly_spend" do
          assert @council_hash[:average_monthly_spend]
        end
        should "contain transaction_count" do
          assert @council_hash[:average_monthly_spend]
        end
        should "contain average_transaction_size" do
          assert @council_hash[:average_transaction_size]
        end
      end
    end
  
  end
end

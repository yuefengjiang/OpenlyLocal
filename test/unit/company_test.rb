require 'test_helper'

class CompanyTest < ActiveSupport::TestCase
  context "The Company class" do
    setup do
      @company = Factory(:company)
      # @supplier = Factory(:supplier, :payee => @company)
    end
  
    should have_many :supplying_relationships
    should validate_presence_of :company_number
  
    should have_db_column :title
    should have_db_column :company_number
    should have_db_column :url
    should have_db_column :normalised_title
    should have_db_column :status
    should have_db_column :wikipedia_url
    should have_db_column :company_type
    should have_db_column :incorporation_date
    
    context "when normalising title" do
      should "normalise title" do
        TitleNormaliser.expects(:normalise_company_title).with('foo bar')
        Company.normalise_title('foo bar')
      end
    end
    
    context "when matching title" do
      should "find company that matches normalised title" do
        raw_title = ' Foo &  Bar Ltd.'
        Company.expects(:first).with(:conditions => {:normalised_title => TitleNormaliser.normalise_company_title(raw_title)})
        Company.matches_title(raw_title)
      end
    end
    
  end
  
  context "An instance of the Company class" do
    setup do
      @company = Factory(:company)
    end
    
    context "when returning title" do

      should "use title attribute by default" do
        @company.update_attribute(:title, 'Foo Incorp')
        assert_equal 'Foo Incorp', @company.title
      end
      
      should "use company number if title is nil" do
        assert_equal "Company number #{@company.company_number}", @company.title
      end
    end
    
    should "use title when converting to_param" do
      @company.title = "some title-with/stuff"
      assert_equal "#{@company.id}-some-title-with-stuff", @company.to_param
    end

    should "skip title when converting to_param if title doesn't exist" do
      assert_equal @company.id.to_s, @company.to_param
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
      
      should "not save normalised title if title is nil" do
        @company.save!
        assert_nil @company.reload.normalised_title
      end
    end

    context 'when returning companies_house_url' do
      # should 'return nil by default' do
      #   assert_nil @company.companies_house_url
      #   @company.company_number = ''
      #   assert_nil @company.companies_house_url
      # end
      
      should "return companies open house url if company_number set" do
        @company.company_number = '012345'
        assert_equal 'http://companiesopen.org/uk/012345/companies_house', @company.companies_house_url
      end
      
      # should "return nil if company_number -1" do
      #   @company.company_number = '-1'
      #   assert_nil @company.companies_house_url
      # end
      
    end

  end
end

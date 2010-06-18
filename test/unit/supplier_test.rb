require 'test_helper'

class SupplierTest < ActiveSupport::TestCase
  subject { @supplier }
  
  context "The Supplier class" do
    setup do
      @supplier = Factory(:supplier)
      @organisation = @supplier.organisation
    end
    
    should have_many :financial_transactions
    should belong_to :company
    should_validate_presence_of :organisation_type, :organisation_id
    
    should have_db_column :uid
    should have_db_column :url
    should have_db_column :name
    should have_db_column :company_number
    should have_db_column :total_spend
    should have_db_column :recent_spend
    
    should 'belong to organisation polymorphically' do
      organisation = Factory(:council)
      assert_equal organisation, Factory(:supplier, :organisation => organisation).organisation
    end
    
    should 'require either name or uid to be present' do
      invalid_supplier = Factory.build(:supplier, :name => nil, :uid => nil)
      assert !invalid_supplier.valid?
      assert_equal 'Either a name or uid is required', invalid_supplier.errors[:base]
      invalid_supplier.name = 'foo'
      assert invalid_supplier.valid?
      invalid_supplier.name = nil
      invalid_supplier.uid = '123'
      assert invalid_supplier.valid?
    end
    
    context 'when validating uniqueness of uid' do
      
      should 'scope to organisation' do
        @supplier.update_attribute(:uid, '123')
        another_supplier = Factory.build(:supplier, :uid => '123') # different org
        assert another_supplier.valid?
        another_supplier.organisation = @organisation
        assert !another_supplier.valid?
      end
      
      should 'allow nil' do
        another_supplier = Factory.build(:supplier, :organisation => @organisation)
        assert another_supplier.valid?
      end
    end
    
    context "when normalising title" do
      should "normalise title" do
        TitleNormaliser.expects(:normalise_company_title).with('foo bar')
        Supplier.normalise_title('foo bar')
      end
    end
  end
  
  context "An instance of the Supplier class" do
    setup do
      @supplier = Factory(:supplier)
    end

    should "alias name as title" do
      assert_equal @supplier.name, @supplier.title
    end
    
    context 'when saving' do
      
      should 'calculate total_spend' do
        @supplier.expects(:calculated_total_spend).returns(42.1)
        @supplier.save!
      end
      
      should 'update total_spend with calculated_total_spend' do
        @supplier.stubs(:calculated_total_spend).returns(42.1)
        @supplier.save!
        assert_equal 42.1, @supplier.reload.total_spend
      end
    end
    
    context 'after creating' do
      setup do
        @company = Factory(:company)
      end
      
      should 'try to match against company' do
        Company.expects(:matches_title).with('Foo company')
        Factory(:supplier, :name => 'Foo company')
      end
      
      should 'and should associate with returned company' do
        Company.stubs(:matches_title).returns(@company)
        supplier = Factory(:supplier, :name => 'Foo company')
        assert_equal @company, supplier.company
      end
      
    end
    
    context 'when returning company_number' do
      should 'return nil if blank?' do
        assert_nil @supplier.company_number
        @supplier.company_number = ''
        assert_nil @supplier.company_number
      end
      
      should "return company_number if set" do
        @supplier.company_number = '012345'
        assert_equal '012345', @supplier.company_number
      end
      
      should "return nil if company_number -1" do
        @supplier.company_number = '-1'
        assert_nil @supplier.company_number
      end
    end
    
    context "when returning associateds" do
      setup do
        @company = Factory(:company)
        @supplier.update_attribute(:company, @company)
        @sibling_supplier = Factory(:supplier, :company => @company)
        @sole_supplier = Factory(:supplier, :company => Factory(:company))
      end

      should "return suppliers belong to same company" do
        assert_equal [@sibling_supplier], @supplier.associateds
      end
      
      should "return empty array if no company for supplier" do
        assert_equal [], Factory(:supplier).associateds
      end
      
      should "return empty array if no other suppliers for company" do
        assert_equal [], @sole_supplier.associateds
      end
      
    end
    
    context "when returning calculated_total_spend" do
      setup do
        @another_supplier = Factory(:supplier)
        @financial_transaction_1 = Factory(:financial_transaction, :supplier => @supplier, :value => 123.45)
        @financial_transaction_2 = Factory(:financial_transaction, :supplier => @supplier, :value => -32.1)
        @financial_transaction_2 = Factory(:financial_transaction, :supplier => @supplier, :value => 22.1)
        @unrelated_financial_transaction = Factory(:financial_transaction, :supplier => @another_supplier, :value => 22.1)
      end

      should "sum all financial transactions for supplier" do
        assert_in_delta (123.45 - 32.1 + 22.1), @supplier.calculated_total_spend, 2 ** -10
      end
    end

  end
end

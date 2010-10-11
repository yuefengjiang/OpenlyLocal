require 'test_helper'

class FinancialTransactionTest < ActiveSupport::TestCase
  subject { @financial_transaction }
  
  context "The FinancialTransaction class" do
    setup do
      @financial_transaction = Factory(:financial_transaction)
    end
    
    # should validate_presence_of :supplier_id
    should validate_presence_of :value
    should validate_presence_of :date
    should belong_to :supplier
    should belong_to :classification
    should have_many :wdtk_requests
    
    should have_db_column :value 
    should have_db_column :uid 
    should have_db_column :description 
    should have_db_column :date
    should have_db_column :department_name 
    should have_db_column :source_url
    should have_db_column :cost_centre 
    should have_db_column :service
    should have_db_column :transaction_type
    should have_db_column :invoice_number
    should have_db_column :csv_line_number
    should have_db_column :date_fuzziness
    should have_db_column :classification_id
    
    should 'validate presence of supplier_id' do
      # NB Shoulda macro not working for some reason
      f=Factory.build(:financial_transaction, :supplier_id => nil)
      assert !f.valid?
      assert f.errors[:supplier_id]
    end                        
    
    context "when building or updating from params" do
      setup do
        @council = Factory(:generic_council)
        @params = [{:value => 1234, :supplier_name => "Foo Ltd", :date =>'2009-04-26'}, {:value => 456, :supplier_name => 'Bar Inc', :date =>'2009-03-19'}]
      end
      
      context "in general" do

        should "build instances of ScrapedObjectResult" do
          transactions = FinancialTransaction.build_or_update(@params, :organisation => @council)
          assert_equal 2, transactions.size
          assert_kind_of ScrapedObjectResult, transactions.first
        end


        should "use params and organisation to create new record" do
          transactions = FinancialTransaction.build_or_update(@params, :organisation => @council)
          assert_equal 1234.0, transactions.first.changes["value"].last
          assert_equal '2009-04-26'.to_date, transactions.first.changes["date"].last
        end

        should "validate new records by default" do
          assert_equal "can't be blank", FinancialTransaction.build_or_update([{:value => ""}], :organisation => @council).first.errors[:value]
        end
      end

      
      context "and save_results is true" do

        should "save financial transactions" do
          assert_difference "FinancialTransaction.count", 2 do
            FinancialTransaction.build_or_update(@params, :organisation => @council, :save_results => true)
          end
        end
        
        should "return instances of ScrapedObjectResult" do
          transactions = FinancialTransaction.build_or_update(@params, :organisation => @council, :save_results => true)
          assert_equal 2, transactions.size
          assert_kind_of ScrapedObjectResult, transactions.first
          assert_equal 'FinancialTransaction', transactions.first.base_object_klass
        end
      end
      
    end
    

    context "when saving" do
      setup do
        supplier = Factory.build(:supplier)
        @financial_transaction = Factory.build(:financial_transaction, :supplier => supplier)
      end
    
      should "save associated supplier" do
        @financial_transaction.save!
        assert !@financial_transaction.supplier.new_record?
      end
      
      context "and supplier isn't valid" do
        setup do
          supplier = Supplier.new
          @financial_transaction = Factory.build(:financial_transaction, :supplier => supplier)
        end
    
        should "not save financial_transaction" do
          assert !@financial_transaction.save
        end
      end
      
      should "queue spending_stat of associated supplier for updating" do
        @supplier = @financial_transaction.supplier
        @supplier.save!
        @spending_stat = @supplier.spending_stat
        Delayed::Job.expects(:enqueue).with(@spending_stat)
        @another_financial_transaction = Factory(:financial_transaction, :description => 'foobar***', :supplier => @supplier, :value => 42)
      end
      
    end

  end
  
  context 'an instance of the FinancialTransaction class' do
    setup do
      @financial_transaction = Factory(:financial_transaction)
    end
    
    should "delegate supplier_name to supplier" do
      assert_equal @financial_transaction.supplier.name, @financial_transaction.supplier_name
    end
    
    should "delegate supplier_uid to supplier" do
      @financial_transaction.supplier.update_attribute(:uid, '6429')
      assert_equal @financial_transaction.supplier.uid, @financial_transaction.supplier_uid
    end
    
    should "delegate supplier_openlylocal_url to supplier" do
      assert_equal @financial_transaction.supplier.openlylocal_url, @financial_transaction.supplier_openlylocal_url
    end
    
    should "delegate organisation_name to supplier organisation" do
      assert_equal @financial_transaction.supplier.organisation.name, @financial_transaction.organisation_name
    end
    
    should "delegate organisation_openlylocal_url to supplier organisation" do
      assert_equal @financial_transaction.supplier.organisation.openlylocal_url, @financial_transaction.organisation_openlylocal_url
    end
    
    should "delegate organisation_type to supplier organisation_type" do
      assert_equal @financial_transaction.supplier.organisation_type, @financial_transaction.organisation_type
    end
    
    context 'when returning title' do
      should 'use date' do
        assert_equal "Transaction with #{@financial_transaction.supplier.title} on #{@financial_transaction.date.to_s(:event_date)}", @financial_transaction.title
      end
      
      should 'use date with fuzziness' do
        @financial_transaction.update_attributes(:date => '2010-04-14', :date_fuzziness => 13)
        assert_equal "Transaction with #{@financial_transaction.supplier.title} in Apr 2010", @financial_transaction.title
      end
      
      should 'use date and uid when uid is set' do
        @financial_transaction.uid = '1234A'
        assert_equal "Transaction 1234A with #{@financial_transaction.supplier.title} on #{@financial_transaction.date.to_s(:event_date)}", @financial_transaction.title
      end
      
      should 'not fail if no date' do
        @financial_transaction.date = nil
        assert_nothing_raised(Exception) { @financial_transaction.title }
      end

      should 'not fail if no supplier' do
        @financial_transaction.supplier = nil
        assert_nothing_raised(Exception) { @financial_transaction.title }
      end
    end
    
    context "when returning related" do
      setup do
        @related_1 = Factory(:financial_transaction, :supplier => @financial_transaction.supplier, :date => 1.year.ago)
        @related_2 = Factory(:financial_transaction, :supplier => @financial_transaction.supplier)
        @unrelated_1 = Factory(:financial_transaction, :supplier => Factory(:supplier))
      end

      should "return only related transactions" do
        related = @financial_transaction.related
        assert related.include?(@related_1)
        assert related.include?(@related_2)
        assert !related.include?(@unrelated_1)
      end
      
      should 'not include self' do 
        assert !@financial_transaction.related.include?(@financial_transaction)
      end
      
      should 'return most recent first' do 
        assert_equal @related_2, @financial_transaction.related.first
      end
    end
    
    should 'return correct url as openlylocal_url' do
      assert_equal "http://#{DefaultDomain}/financial_transactions/#{@financial_transaction.to_param}", @financial_transaction.openlylocal_url
    end
     
    context "when returning averaged_date_and_value" do
      should "return array with just date and value array if no date_fuzziness for transaction" do
        assert_equal [[@financial_transaction.date, @financial_transaction.value]], @financial_transaction.averaged_date_and_value
      end
      
      context "and financial_transaction has date_fuzziness" do

        should "return arrary of single date and value array when it doesn't go over more than one month" do
          slightly_fuzzy_ft = Factory(:financial_transaction, :date_fuzziness => 5, :date => '10-12-2009')
          assert_equal [['10-12-2009'.to_date, slightly_fuzzy_ft.value]], slightly_fuzzy_ft.averaged_date_and_value
        end
        
        should "return dates and values of transaction averaged over time time period extends over more than one month" do
          quite_fuzzy_ft = Factory(:financial_transaction, :date_fuzziness => 15, :date => '10-12-2009')
          averaged_results = quite_fuzzy_ft.averaged_date_and_value
          assert_equal 2, averaged_results.size
          assert_equal '25-11-2009'.to_date, averaged_results.first.first #doesn't really matter what day is as we wo't use that
          assert_equal '25-12-2009'.to_date, averaged_results.last.first
          assert_in_delta quite_fuzzy_ft.value/2, averaged_results.first.last, 2 ** -10
          assert_in_delta quite_fuzzy_ft.value/2, averaged_results.last.last, 2 ** -10
        end
        
        should "return averaged dates and values of transaction if period extends over several months" do
          quite_fuzzy_ft = Factory(:financial_transaction, :date_fuzziness => 43, :date => '10-12-2009')
          averaged_results = quite_fuzzy_ft.averaged_date_and_value
          assert_equal 4, averaged_results.size
          assert_equal '28-10-2009'.to_date, averaged_results.first.first #doesn't really matter what day is as we wo't use that
          assert_equal '28-01-2010'.to_date, averaged_results.last.first
          assert_in_delta quite_fuzzy_ft.value/4, averaged_results.first.last, 2 ** -10
          assert_in_delta quite_fuzzy_ft.value/4, averaged_results.last.last, 2 ** -10
        end
      end
    end 
    
    context "when setting value" do

      should "assign value as expected" do
        assert_equal 34567.23, Factory(:financial_transaction, :value => 34567.23).value
        assert_equal -34567.23, Factory(:financial_transaction, :value => -34567.23).value
      end

      should "strip out commas" do
        assert_equal 34567.23, Factory(:financial_transaction, :value => '34,567.23').value
        assert_equal 34567890.23, Factory(:financial_transaction, :value => '34,567,890.23').value
      end

      should "strip out spaces" do
        assert_equal 34567.23, Factory(:financial_transaction, :value => '34, 567.23 ').value
      end

      should "treat brackets as negative numbers" do
        assert_equal -34567.23, Factory(:financial_transaction, :value => '(34,567.23)').value
      end

      should "strip out pound signs" do
        assert_equal 3467.23, Factory(:financial_transaction, :value => '£3467.23').value
      end
    end

    context "when setting date" do

      should "set date as expected" do
        date = 30.days.ago.to_date
        assert_equal date, Factory(:financial_transaction, :date => date).date
      end

      should "convert UK date if in slash format" do
        assert_equal '2006-04-01', Factory(:financial_transaction, :date => '01/04/2006').date.to_s
      end

      should "not convert date if not in slash format" do
        assert_equal '2006-01-04', Factory(:financial_transaction, :date => '2006-01-04').date.to_s
      end

    end

    context 'when setting department_name' do
      should 'squish spaces' do
        assert_equal 'Foo Department', Factory.build(:financial_transaction, :department_name => ' Foo   Department   ').department_name
      end

      should 'replace mispellings' do
        assert_equal 'Children\'s Department', Factory.build(:financial_transaction, :department_name => 'Childrens\' Department ').department_name
        assert_equal 'Children\'s Department', Factory.build(:financial_transaction, :department_name => 'Childrens Department ').department_name
      end
      
      should 'remove multiple and utf8 spaces' do
        assert_equal 'Housing and Other Stuff Department', Factory.build(:financial_transaction, :department_name => "    Housing#{160.chr}and Other    Stuff Department\n ").department_name
      end
      
      should 'not have a problem if department_name is nil' do
        assert_nil Factory.build(:financial_transaction, :department_name => nil).department_name
      end
    end
    
    context "when returning full description" do

      should "return nil by if description and service blank" do
        assert_nil @financial_transaction.full_description
        @financial_transaction.attributes = {:description => '', :service => ''}
        assert_nil @financial_transaction.full_description
      end
      
      should "return description if description not blank" do
        @financial_transaction.description = 'foo description'
        assert_equal 'foo description', @financial_transaction.full_description
      end
      
      should "return service if service not blank" do
        @financial_transaction.service = 'bar service'
        assert_equal 'bar service', @financial_transaction.full_description
      end
      
      should "return description and service if description and service not blank" do
        @financial_transaction.description = 'foo description'
        @financial_transaction.service = 'bar service'
        assert_equal 'foo description (bar service)', @financial_transaction.full_description
      end
    end
    
    context "when returning value_with_two_dec_places" do

      should "return value as string with two decimal places" do
        assert_equal '123.45', FinancialTransaction.new(:value => 123.45123).value_to_two_dec_places
        assert_equal '123456.79', FinancialTransaction.new(:value => 123456.789).value_to_two_dec_places
        assert_equal '123456.00', FinancialTransaction.new(:value => 123456).value_to_two_dec_places
        assert_equal '123456.00', FinancialTransaction.new(:value => 123456.0).value_to_two_dec_places
      end

      should "return nil when no value" do
        assert_nil FinancialTransaction.new.value_to_two_dec_places
      end
    end
    
    context "when returning organisation" do

      should "return supplier organisation" do
        assert_equal @financial_transaction.supplier.organisation, @financial_transaction.organisation
      end
      
      should 'return @organisation instance variable if set' do
        dummy_org = stub
        fin_trans = FinancialTransaction.new
        fin_trans.instance_variable_set(:@organisation, dummy_org)
        assert_equal dummy_org, fin_trans.organisation
      end
      
      should 'return nil if @organisation instance variable not set' do
        assert_nil FinancialTransaction.new.organisation
      end
    end
    
    context "when returning csv data" do
      setup do
        @financial_transaction.description = "Some transaction"
      end
      
      should "return array" do
        assert_kind_of Array, @financial_transaction.csv_data
      end
      
      should "return same number of elements as CsvMappings" do
        assert_equal FinancialTransaction::CsvMappings.size, @financial_transaction.csv_data.size
      end
      
      should "map attributes to csv heading" do
        expected_position = FinancialTransaction.csv_headings.index(:description)
        assert_equal "Some transaction", @financial_transaction.csv_data[expected_position]
      end
      
      should "map non-attributes to csv heading" do
        expected_position = FinancialTransaction.csv_headings.index(:supplier_openlylocal_id)
        assert_equal @financial_transaction.supplier_id, @financial_transaction.csv_data[expected_position]
      end
      
      should "output date as ISO 8601" do
        expected_position = FinancialTransaction.csv_headings.index(:date)
        assert_equal @financial_transaction.reload.date.to_s(:db), @financial_transaction.csv_data[expected_position]
      end
      
      should "output datetime as ISO 8601" do
        expected_position = FinancialTransaction.csv_headings.index(:created_at)
        assert_equal @financial_transaction.created_at.iso8601, @financial_transaction.csv_data[expected_position]
      end
    end

    context 'when setting supplier_name' do
      setup do
        @existing_supplier = Factory(:supplier, :name => 'Foo Supplier')
        @organisation = @existing_supplier.organisation
      end
      
      context 'and organisation not set' do
        setup do
          @fin_trans = FinancialTransaction.new
        end
        
        should 'should not try to find supplier' do
          Supplier.expects(:find).never
          @fin_trans.supplier_name = 'Foo Supplier'
        end
        
        should "should instantiate new supplier if it doesn't exist" do
          @fin_trans.supplier_name = 'Bar Supplier'
	        assert_kind_of Supplier, supplier = @fin_trans.supplier
	        assert_equal 'Bar Supplier', supplier.name
	      end
	      
        should "should update existing supplier instance if already set" do
          @fin_trans.supplier_uid = 'ab123'
          @fin_trans.supplier_name = 'Bar Supplier'
 	        assert_kind_of Supplier, supplier = @fin_trans.supplier
 	        assert_equal 'Bar Supplier', supplier.name
 	        assert_equal 'ab123', supplier.uid
 	      end
	    end
	 
	    context 'and organisation set' do
	      setup do
	        @fin_trans = FinancialTransaction.new(:organisation => @organisation)
	      end
	      
	      should 'should find supplier for organisation if it exists' do
	        @fin_trans.supplier_name = 'Foo Supplier'
	        assert_equal @existing_supplier, @fin_trans.supplier
	      end
	      
	      should "should instantiate new supplier for organisation if it doesn't exist" do
	        @fin_trans.supplier_name = 'Bar Supplier'
	        assert_kind_of Supplier, supplier = @fin_trans.supplier
	        assert_equal 'Bar Supplier', supplier.name
	        assert_equal @organisation, supplier.organisation
	      end
	      
 	      should "update existing supplier for organisation if set" do
 	        @fin_trans.supplier_id = 'abc123'
 	        @fin_trans.supplier_name = 'Bar Supplier'
 	        assert_kind_of Supplier, supplier = @fin_trans.supplier
 	        assert_equal 'Bar Supplier', supplier.name
 	        assert_equal @organisation, supplier.organisation
 	      end
	    end
	  end
	 
    context 'when setting supplier_uid' do
      setup do
        @existing_supplier = Factory(:supplier, :name => 'Foo Supplier', :uid => "ab123")
        @organisation = @existing_supplier.organisation
      end

      context 'and organisation not set' do
        setup do
          @fin_trans = FinancialTransaction.new
        end

        should 'should not try to find supplier' do
          Supplier.expects(:find).never
          @fin_trans.supplier_name = 'Foo Supplier'
        end

        should "should instantiate new supplier with given if it doesn't exist" do
          @fin_trans.supplier_uid = 'ab123'
 	        assert_kind_of Supplier, supplier = @fin_trans.supplier
 	        assert_equal 'ab123', supplier.uid
 	      end
 	      
 	      should "update existing supplier instance if already set" do
 	        @fin_trans.supplier_name = 'Bar Supplier'
          @fin_trans.supplier_uid = 'ab123'
 	        assert_kind_of Supplier, supplier = @fin_trans.supplier
 	        assert_equal 'ab123', supplier.uid
 	        assert_equal 'Bar Supplier', supplier.name
 	      end
 	    end

 	    context 'and organisation set' do
 	      setup do
 	        @fin_trans = FinancialTransaction.new(:organisation => @organisation)
 	      end

 	      should 'find supplier for organisation if it exists' do
 	        @fin_trans.supplier_name = 'Foo Supplier'
 	        assert_equal @existing_supplier, @fin_trans.supplier
 	      end

 	      should "instantiate new supplier for organisation if it doesn't exist" do
 	        @fin_trans.supplier_name = 'Bar Supplier'
 	        assert_kind_of Supplier, supplier = @fin_trans.supplier
 	        assert_equal 'Bar Supplier', supplier.name
 	        assert_equal @organisation, supplier.organisation
 	      end
 	      
 	    end
 	  end

	  context 'when setting organisation' do
	    setup do
	      @organisation = Factory(:police_force)
	    end
	    
	    context 'and supplier not set' do
	      setup do
	        @fin_trans = FinancialTransaction.new
	      end
	      
	      should 'set instance variable' do
	        @fin_trans.organisation = @organisation
	        assert_equal @organisation, @fin_trans.instance_variable_get(:@organisation)
	      end
	      
	      should "should not do anything with supplier" do
	        @fin_trans.organisation = @organisation
	        assert_nil @fin_trans.supplier
	      end
	    end
	 
	    context 'and supplier is set' do
	      
	      should 'should assign organisation to supplier' do
	        @fin_trans = FinancialTransaction.new(:supplier_name => 'Bar Supplier')
	        @fin_trans.organisation = @organisation
	        assert_equal @organisation, @fin_trans.supplier.organisation
	      end
	      
	      should 'should try to match existing suppliers' do
	        exist_supplier = Factory(:supplier, :organisation => @organisation, :name => 'Bar Supplier')
	        @fin_trans = FinancialTransaction.new(:supplier_name => 'Bar Supplier')
	        @fin_trans.organisation = @organisation
	        assert_equal exist_supplier, @fin_trans.supplier
	      end
	      
	    end
	  end

    context "when setting supplier vat number" do
      setup do
        @fin_trans = FinancialTransaction.new
      end
      
      should "instantiate supplier if not set yet" do
        @fin_trans.supplier_vat_number = 'GB12345'
        assert_kind_of Supplier, @fin_trans.supplier
      end
      
      should 'assign to vat_number instance_variable' do
        @fin_trans.supplier_vat_number = 'GB12345'
        assert_equal 'GB12345', @fin_trans.supplier.instance_variable_get(:@vat_number)
      end
      
      should "not instantiate new supplier if set" do
        @fin_trans.supplier_name = 'Bar Supplier'
        @fin_trans.supplier_vat_number = 'GB12345'
        assert_equal 'Bar Supplier', @fin_trans.supplier.name
      end
      
    end
    
    context 'when setting proclass_classification' do
      setup do
        @proclass_class_1 = Factory(:classification, :grouping => 'Proclass10.1', :uid => '10010')
        @proclass_class_2 = Factory(:classification, :grouping => 'Proclass10.1', :uid => '10020', :title => 'Foo Bar')
        @fin_trans = FinancialTransaction.new
      end

      should 'match with classification appropriate to version' do
        Classification.expects(:first).with(:conditions => {:grouping => 'Proclass10.1', :title => 'Foo Bar'})
        @fin_trans.proclass10_1 = 'Foo Bar'
        Classification.expects(:first).with(:conditions => {:grouping => 'Proclass8.3', :title => 'Foo Baz'})
        @fin_trans.proclass8_3 = 'Foo Baz'
      end
            
      should 'match with classification uid if number given' do
        Classification.expects(:first).with(:conditions => {:grouping => 'Proclass10.1', :uid => '10020'})
        @fin_trans.proclass10_1 = '10020'
      end
            
      should 'assign returned classification' do
        @fin_trans.proclass10_1 = 'Foo Bar'
        assert_equal @proclass_class_2, @fin_trans.classification
      end

      should 'deassign existing classification if already set and no such classification' do
        @fin_trans.classification = @proclass_class_1
        @fin_trans.proclass10_1 = 'Foo Baz'
        assert_nil @fin_trans.classification
      end

 	  end


    # This is sort of integration test to see that all is well
    should "create supplier when financial transaction saved" do
      ft = Factory.build(:financial_transaction, :supplier => nil)
      ft.supplier_vat_number = 'GB12345'
      ft.organisation = Factory(:council)
      ft.supplier_name = 'Foo Supplier'
      assert_difference "Supplier.count", 1 do
        ft.save!
      end
      assert_equal 'Foo Supplier', ft.reload.supplier.name
    end
    
    should 'be able to be created when supplied with necessary supplier params' do
      # This is sort of integration test for whole lifecycle of saving with supplier info, as happens when parsing csv files
      org = Factory(:police_force)
      ft = FinancialTransaction.new(:value => "32.40", :date => 2.days.ago, :supplier_name => 'Foo Inc', :organisation => org)
      assert ft.save
      assert ft.errors.empty?
      assert !ft.supplier.new_record?
    end

    context "when returning foi_message_body" do
      setup do
        @financial_transaction.update_attributes( :uid => '1234')
      end

      should "return boilerplate" do
        assert_match /Freedom of Information Act 2000/, @financial_transaction.foi_message_body
      end
      
      should "include information about transaction" do
        assert_match /payment/, @financial_transaction.foi_message_body
        assert_match /#{@financial_transaction.supplier_name}/, @financial_transaction.foi_message_body
        assert_match /£#{@financial_transaction.value}/, @financial_transaction.foi_message_body
        assert_match /#{@financial_transaction.date.to_s(:custom_short)}/, @financial_transaction.foi_message_body
        assert_match /transaction id: #{@financial_transaction.uid}/i, @financial_transaction.foi_message_body
      end
      
      should 'use date_with_fuzziness for date' do
        @financial_transaction.update_attributes(:date => '2010-04-15', :date_fuzziness => 14)
        assert_match /date.+: apr 2010/i, @financial_transaction.foi_message_body
      end
    end
  end                      
end

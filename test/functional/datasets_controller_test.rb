require File.expand_path('../../test_helper', __FILE__)

class DatasetsControllerTest < ActionController::TestCase
  def setup
    @dataset = Factory(:dataset)
    @dataset_family = Factory(:dataset_family, :dataset => @dataset, :calculation_method => "sum")
  end
  
  # routing tests
  should "route to show" do
    @council = Factory(:council)
    assert_routing("datasets/123", {:controller => "datasets", :action => "show", :id => "123"})
  end
  
  should "route with council to show" do
    @council = Factory(:council)
    assert_routing("councils/42/datasets/123", {:controller => "datasets", :action => "show", :id => "123", :area_id => "42", :area_type => "Council"})
  end
  
  # index test
  context "on GET to :index" do
    context "with basic request" do
      setup do
        get :index
      end

      should assign_to(:datasets) { Dataset.all}
      should respond_with :success
      should render_template :index
      should "list datasets" do
        assert_select "li a", @dataset.title
      end
      
      should 'show title' do
        assert_select "title", /datasets/i
      end
      
    end
  end
    
  # show test
  context "on GET to :show" do

    context "with basic request" do
      setup do
        get :show, :id => @dataset.id
      end

      should assign_to :dataset
      should respond_with :success
      should render_template :show

      should "include statistical dataset in page title" do
        assert_select "title", /#{@dataset.title}/
      end

      should "list statistical dataset attributes" do
        assert_select '.attributes dd', /#{@dataset.url}/
      end
      
      should "list associated dataset families" do
        assert_select 'li a', /#{@dataset_family.title}/
      end
      
      should "not show datapoint table" do
        assert_select "table.statistics", false
      end
    end
    
    context "with family that has calculated_datapoints_for_councils" do
      setup do
        @council_1, @council_2 = Factory(:council, :name => "Council 1"), Factory(:council, :name => "Council 2")
        dummy_datapoints = [BareDatapoint.new(:area => @council_1, :value => 123, :subject => @dataset), BareDatapoint.new(:area => @council_2, :value => 456, :subject => @dataset)]
        Dataset.any_instance.stubs(:calculated_datapoints_for_councils).returns(dummy_datapoints)
        get :show, :id => @dataset.id
      end

      should assign_to :dataset
      should assign_to :datapoints
      should respond_with :success
      should render_template :show
      
      should "show council datapoints in table" do
        assert_select "table.statistics tr", /#{@council_1.name}/ do
          assert_select ".value", /123/
        end
      end
      
      should "show link to show dataset just for council" do
        assert_select "table.statistics tr", /#{@council_1.name}/ do
          assert_select ".more_info a[href*=?]", "/councils/#{@council_1.to_param}/datasets/#{@dataset.id}"
        end
      end
         
    end

    context "with given area" do
      context "and basic request" do
        setup do
          @council = Factory(:council)
          
          @another_dataset_family = Factory(:dataset_family, :dataset => @dataset, :calculation_method => "sum")
          @dataset_topic = Factory(:dataset_topic, :dataset_family => @dataset_family)
          @another_dataset_topic = Factory(:dataset_topic, :dataset_family => @another_dataset_family)

          @datapoint = Factory(:datapoint, :area =>@council, :dataset_topic => @dataset_topic)
          @datapoint_for_another_topic = Factory(:datapoint, :area => @council, :dataset_topic => @another_dataset_topic) # this will have value of one more than @datapoint

          get :show, :id => @dataset.id, :area_type => "Council", :area_id => @council.id
        end

        should assign_to :dataset
        should assign_to(:area) { @council }
        should respond_with :success
        should render_template :show
        
        should "assign to datapoints bare datapoints with correct values in desc order" do
           dps = assigns(:datapoints)
           assert_kind_of BareDatapoint, dps.first
           assert_equal 2, dps.size
           assert_equal @datapoint_for_another_topic.value, dps.first.value
           assert_equal @datapoint_for_another_topic.dataset_family, dps.first.subject
        end

        should "include dataset in page title" do
          assert_select "title", /#{@dataset.title}/
        end

        should "include area in page title" do
          assert_select "title", /#{@council.name}/
        end

        should "list datapoints" do
          assert_select ".datapoints" do
            assert_select '.description', /#{@dataset_family.title}/
            assert_select '.description', /#{@another_dataset_family.title}/
          end
        end

        should "not list associated dataset families" do
          assert_select '#relationships li', :text => /#{@dataset_family.title}/, :count => 0
        end
        
        should "show links to more detailed data" do
          assert_select ".more_info a[href*=?]", "/councils/#{@council.to_param}/dataset_families/#{@dataset_family.id}"
        end
      end
    end

  end

  # edit tests
  context "on get to :edit a Dataset without auth" do
    setup do
      get :edit, :id => @dataset.id
    end

    should respond_with 401
  end

  context "on get to :edit a Dataset" do
    setup do
      stub_authentication
      get :edit, :id => @dataset.id
    end

    should assign_to :dataset
    should respond_with :success
    should render_template :edit
    should_not set_the_flash
    should "display a form" do
     assert_select "form#edit_dataset_#{@dataset.id}"
    end

  end

  # update tests
  context "on PUT to :update a Dataset without auth" do
    setup do
      put :update, { :id => @dataset.id,
                     :dataset => { :title => "New title"}}
    end

    should respond_with 401
  end

  context "on PUT to :update a Dataset" do
    setup do
      stub_authentication
      put :update, { :id => @dataset.id,
                     :dataset => { :title => "New title"}}
    end

    should assign_to :dataset
    should redirect_to( "the show page for dataset") { dataset_url(@dataset.reload) }
    should set_the_flash.to(/Successfully updated/)

    should "update dataset" do
      assert_equal "New title", @dataset.reload.title
    end
  end


end

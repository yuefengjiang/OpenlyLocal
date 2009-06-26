require 'test_helper'

class DatasetsControllerTest < ActionController::TestCase
  def setup
    @dataset = Factory(:dataset)
  end
  
  # index test
  context "on GET to :index without auth" do
    setup do
      get :index
    end
  
    should_respond_with 401
  end

  context "on GET to :index" do
    setup do
      stub_authentication
      get :index
    end
  
    should_assign_to(:datasets) { Dataset.find(:all)}
    should_respond_with :success
    should_render_template :index
    should "list datasets" do
      assert_select "li a", @dataset.title
    end
    
    should "not show share block" do
      assert_select "#share_block", false
    end
  end  

  # show test
  context "on GET to :show without auth" do
    setup do
      get :show, :id => @dataset.id
    end
  
    should_respond_with 401
  end

  context "on GET to :show for first record" do
    setup do
      @council = Factory(:council)
      stub_authentication
      get :show, :id => @dataset.id
    end
  
    should_assign_to(:dataset) { @dataset}
    should_respond_with :success
    should_render_template :show
    # should_assign_to(:councils) { @dataset.councils }
  
    # should "list all councils" do
    #   assert_select "#councils li", @dataset.councils.size do
    #     assert_select "a", @council.title
    #   end
    # end
    # 
    # should "list all parsers" do
    #   assert_select "#parsers li" do
    #     assert_select "a", @parser.title
    #   end
    # end
    # 
    # should "not show share block" do
    #   assert_select "#share_block", false
    # end
  end  
  
  # new test
  context "on GET to :new without auth" do
    setup do
      get :new
    end
  
    should_respond_with 401
  end

  context "on GET to :new" do
    setup do
      stub_authentication
      get :new
    end
  
    should_assign_to(:dataset)
    should_respond_with :success
    should_render_template :new
  
    should "show form" do
      assert_select "form#new_dataset"
    end
  end  
  
  # create test
   context "on POST to :create" do
    
     context "without auth" do
       setup do
         post :create, :dataset => {:title => "New Dataset"}
       end

       should_respond_with 401
     end

     context "with valid params" do
       setup do
         stub_authentication
         post :create, :dataset => Factory.attributes_for(:dataset)
       end
     
       should_change "Dataset.count", :by => 1
       should_assign_to :dataset
       should_redirect_to( "the show page for dataset") { dataset_url(assigns(:dataset)) }
       should_set_the_flash_to "Successfully created dataset"
     
     end
     
     context "with invalid params" do
       setup do
         stub_authentication
         post :create, :dataset => {:title => "Dataset title"}
       end
     
       should_not_change "Dataset.count"
       should_assign_to :dataset
       should_render_template :new
       should_not_set_the_flash
     end
  
   end  
  
   # edit test
   context "on GET to :edit without auth" do
     setup do
       get :edit, :id => @dataset
     end

     should_respond_with 401
   end

   context "on GET to :edit with existing record" do
     setup do
       stub_authentication
       get :edit, :id => @dataset
     end
  
     should_assign_to(:dataset)
     should_respond_with :success
     should_render_template :edit
  
     should "show form" do
       assert_select "form#edit_dataset_#{@dataset.id}"
     end
   end  
  
  # update test
  context "on PUT to :update" do
    context "without auth" do
      setup do
        put :update, :id => @dataset.id, :dataset => { :title => "New title" }
      end

      should_respond_with 401
    end
    
    context "with valid params" do
      setup do
        stub_authentication
        put :update, :id => @dataset.id, :dataset => { :title => "New title" }
      end
    
      should_not_change "Dataset.count"
      should_change "@dataset.reload.title", :to => "New title"
      should_assign_to :dataset
      should_redirect_to( "the show page for dataset") { dataset_path(assigns(:dataset)) }
      should_set_the_flash_to "Successfully updated dataset"
    
    end
    
    context "with invalid params" do
      setup do
        stub_authentication
        put :update, :id => @dataset.id, :dataset => {:title => ""}
      end
    
      should_not_change "Dataset.count"
      should_not_change "@dataset.reload.title"
      should_assign_to :dataset
      should_render_template :edit
      should_not_set_the_flash
    end
  
  end  
end

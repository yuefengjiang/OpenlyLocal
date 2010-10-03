require 'test_helper'

class EntitiesControllerTest < ActionController::TestCase
  def setup
    @entity = Factory(:entity)
    @another_entity = Factory(:entity)
  end
  
  context "on GET to :index" do
    
    context "with basic request" do
      setup do
        get :index
      end

      should_assign_to(:entities) { Entity.find(:all)}
      should respond_with :success
      should render_template :index
      should "list entities" do
        assert_select "li a", @entity.title
      end
      
      should "show share block" do
        assert_select "#share_block"
      end

      should "show api block" do
        assert_select "#api_info"
      end
      
      should 'show title' do
        assert_select "title", /quangos/i
      end
    end
    
    context "with xml request" do
      setup do
        get :index, :format => "xml"
      end

      should_assign_to(:entities) { Entity.find(:all) }
      should respond_with :success
      should_render_without_layout
      should respond_with_content_type 'application/xml'
    end

    context "with json requested" do
      setup do
        get :index, :format => "json"
      end

      should_assign_to(:entities) { Entity.find(:all) }
      should respond_with :success
      should_render_without_layout
      should respond_with_content_type 'application/json'
    end
  end
  
  context "on GET to :show" do
    context "in general" do
      setup do
        get :show, :id => @entity.id
      end

      should assign_to(:entity) { @entity}
      should respond_with :success
      should render_template :show
      # should assign_to(:organisation) { @organisation }

      should "show entity name in title" do
        assert_select "title", /#{@entity.title}/
      end

    end
  end
  
  # new test
  context "on GET to :new without auth" do
    setup do
      get :new
    end
  
    should respond_with 401
  end

  context "on GET to :new" do
    setup do
      stub_authentication
      get :new
    end
  
    should_assign_to(:entity)
    should respond_with :success
    should render_template :new
  
    should "show form" do
      assert_select "form#new_entity"
    end
  end  
  
  # create test
   context "on POST to :create" do
    
     context "without auth" do
       setup do
         post :create, :entity => {:title => "New Entity", :website => "http:://new_entity.com"}
       end

       should respond_with 401
     end

     context "with valid params" do
       setup do
         stub_authentication
         post :create, :entity => {:title => "New Entity", :website => "http:://new_entity.com"}
       end
     
       should_change("The number of entities", :by => 1) { Entity.count }
       should_assign_to :entity
       should_redirect_to( "the show page for entity") { entity_path(assigns(:entity)) }
       should set_the_flash.to "Successfully created entity"
     
     end
     
     context "with invalid params" do
       setup do
         stub_authentication
         post :create, :entity => {:website => "http:://new_force.com"}
       end
     
       should_not_change("The number of entities") { Entity.count }
       should_assign_to :entity
       should render_template :new
       should_not set_the_flash
     end
  
   end  
  
   # edit test
   context "on GET to :edit without auth" do
     setup do
       get :edit, :id => @entity
     end

     should respond_with 401
   end

   context "on GET to :edit with existing record" do
     setup do
       stub_authentication
       get :edit, :id => @entity
     end
  
     should_assign_to(:entity)
     should respond_with :success
     should render_template :edit
  
     should "show form" do
       assert_select "form#edit_entity_#{@entity.id}"
     end
   end  
  
  # update test
  context "on PUT to :update" do
    context "without auth" do
      setup do
        put :update, :id => @entity.id, :entity => { :title => "New Name", :website => "http://new.name.com"}
      end

      should respond_with 401
    end
    
    context "with valid params" do
      setup do
        stub_authentication
        put :update, :id => @entity.id, :entity => { :title => "New Name", :website => "http://new.name.com"}
      end
    
      should_not_change("The number of entities") { Entity.count }
      should_change("The entity name", :to => "New Name") { @entity.reload.title }
      should_change("The entity website", :to => "http://new.name.com") { @entity.reload.website }
      should_assign_to :entity
      should_redirect_to( "the show page for entity") { entity_path(assigns(:entity)) }
      should_set_the_flash_to "Successfully updated entity"
    
    end
    
    context "with invalid params" do
      setup do
        stub_authentication
        put :update, :id => @entity.id, :entity => {:title => ""}
      end
    
      should_not_change("The number of entities") { Entity.count }
      should_not_change("The entity name") { @entity.reload.title }
      should_assign_to :entity
      should render_template :edit
      should_not set_the_flash
    end
  
  end  
  
  # delete tests
  context "on delete to :destroy a entity without auth" do
    setup do
      delete :destroy, :id => @entity.id
    end

    should respond_with 401
  end

  context "on delete to :destroy a entity" do

    setup do
      stub_authentication
      delete :destroy, :id => @entity.id
    end

    should "destroy hyperlocal_site" do
      assert_nil Entity.find_by_id(@entity.id)
    end
    should_redirect_to ( "the entities page") { entities_url }
    should set_the_flash.to( /Successfully destroyed/)
  end
  
  context "on GET to :show_spending" do
    should "route open councils to index with show_open_status true" do
      assert_routing("entities/1/spending", {:controller => "entities", :action => "show_spending", :id => "1"})
    end
    
    context "in general" do
      setup do
        @supplier_1 = Factory(:supplier, :organisation => @entity)
        @high_spending_supplier = Factory(:supplier, :organisation => @entity)
        @financial_transaction_1 = Factory(:financial_transaction, :supplier => @supplier_1)
        @financial_transaction_2 = Factory(:financial_transaction, :value => 1000000, :supplier => @high_spending_supplier)
        get :show_spending, :id => @entity.id
      end

      should respond_with :success
      should render_template :show_spending
      should_not set_the_flash
      should assign_to :entity

      # should 'assign to suppliers ordered by total spend' do
      #   assert assigns(:suppliers).include?(@supplier_1)
      #   assert assigns(:suppliers).include?(@high_spending_supplier)
      #   assert_equal @high_spending_supplier, assigns(:suppliers).first
      # end
      # 
      # should 'assign to financial_transactions ordered by size' do
      #   assert assigns(:financial_transactions).include?(@financial_transaction_1)
      #   assert assigns(:financial_transactions).include?(@financial_transaction_2)
      #   assert_equal @financial_transaction_2, assigns(:financial_transactions).first
      # end

      should "have basic title" do
        assert_select "title", /spending dashboard/i
      end
      
      should "include entity in basic title" do
        assert_select "title", /#{@entity.title}/i
      end
      
      should 'list suppliers' do
        assert_select '#suppliers a', /#{@supplier_1.title}/
      end
      
      should 'list transactions' do
        assert_select '#financial_transactions a', /#{@supplier_1.title}/
      end
    end
    
    context "and no spending data" do
      setup do
        get :show_spending, :id => @another_entity.id
      end

      should respond_with :success
      should render_template :show_spending
      should_not set_the_flash
      should assign_to :entity

      should "show message" do
        assert_select "p.alert", /spending data/i
      end
      should "not show dashboard" do
        assert_select "div.dashboard", false
      end
    end
  end
  
end